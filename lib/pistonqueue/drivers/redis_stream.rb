require 'redis'
require 'async'
require 'async/semaphore'

require_relative '../abstract_driver'
require_relative '../utils/logging'
require_relative '../utils/retry_handler'

module Pistonqueue
  class RedisStream < ::Pistonqueue::AbstractDriver
    include ::Pistonqueue::Logging
    include ::Pistonqueue::RetryHandler

    # method description : redis initialization.
    def initialize(config:)
      @config = config
      @redis = Redis.new(url: @config.redis_url)
    end

    # method description : add new data into redis stream.
    # parameters :
    # - topic : target 'topic' to be sent, for example : 'topic_io'.
    # - data : data object that will be sent to the topic, for example : { order_id: 'xyz-1', total_payment: 250000 }.
    def produce(topic:, data: {})
      raise ArgumentError, "The 'data' parameter value must contain an object." if !(data.is_a?(Hash) && data.any?)

      @redis.xadd(topic, { payload: data.to_json }, maxlen: ["~", @config.maxlen.to_i])
    end

    # method description : fetch data from redis stream and process the data with high concurrency.
    # parameters :
    # - topic : target 'topic' to be sent, for example : 'topic_io'.
    # - fiber_limit : maximum total fiber, for example : 500.
    # - is_retry : the consumer will run the retry process, for example : true.
    # - options : additional parameters to support how the consumer driver works, for example : { group: 'group-1', consumer: 'consumer-1' }.
    def consume(topic:, fiber_limit:, is_retry: false, options: {}, service_block:)
      group, consumer = fetch_group_and_consumer(options: options)

      setup_group(topic: topic, group: group)

      sleep_time = 1
      if is_retry
        sleep_time = 5
        logger.info("🚀 Retry consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}.")
      else
        logger.info("🚀 Consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}.")
      end

      Async do |task|
        semaphore = Async::Semaphore.new(fiber_limit)

        loop do
          begin
            messages = @redis.xreadgroup(group, consumer, topic, '>', count: @config.redis_batch_size.to_i, block: @config.redis_block_duration.to_i) # read new messages from redis stream as part of a consumer group.
            next task.sleep(sleep_time) if messages.nil? || messages.empty?

            messages.each do |_stream, entries|
              entries.each do |id, data|
                semaphore.async do
                  payload = JSON.parse(data["payload"])

                  if is_retry # retry process with job.
                    max_retry = @config.max_retry.to_i

                    begin
                      # tier 2: retry with exponential backoff and jitter at the scheduler job level.
                      ExponentialBackoffJitter.with_retry(max_retries: max_retry) do
                        service_block.call(payload)
                      end

                      logger.info("✅ Retry [#{topic}] id: #{id} success.")
                    rescue => ex
                      error_msg = ex.message
                      previous_topic = topic.sub('_retry', '')

                      # tier 3: dead letter queue (permanent failure).
                      move_to_dlq(dlq_topic: "#{previous_topic}_dlq", original_message_id: id, original_data: payload, error_message: error_msg)
                      
                      logger.error("💀 [#{previous_topic}] max retries reached, moved to dlq topic.")
                    end

                    acknowledge(topic: topic, group: group, message_id: id)
                  else # main process.
                    max_local_retry = @config.max_local_retry.to_i
                    total_trials = 0

                    begin
                      # tier 1: retry with exponential backoff and jitter at the consumer level.
                      ExponentialBackoffJitter.with_retry(max_retries: max_local_retry) do
                        total_trials += 1
                        service_block.call(payload)
                      end

                      # acknowledge the data so that it is not sent again to the consumer.
                      acknowledge(topic: topic, group: group, message_id: id)

                      logger.info("✅ [#{topic}] id: #{id} success.")
                    rescue => ex
                      # do a retry outside the consumer.
                      produce(topic: "#{topic}_retry", data: payload)

                      logger.warn("🔄 [#{topic}] failed. moved to retry topic (total trials : #{total_trials}).")
                    end
                  end
                end
              end
            end
          rescue => e
            logger.error("Consumer #{consumer} on topic [#{topic}] error : #{e.message}.")
          end
        end
      end
    end

    private
      # method description : register consumer group to redis stream.
      # parameters :
      # - topic : target 'topic' to be sent, for example : 'topic_io'.
      # - group : a mechanism that allows multiple workers (consumers) to share the workload of the same stream, for example : 'group-1'.
      def setup_group(topic:, group:)
        @redis.xgroup(:create, topic, group, '$', mkstream: true)
      rescue Redis::CommandError => e
        logger.warn("Group #{group} is already in topic [#{topic}].")
      end

      # method description : take 'group' and 'consumer' data from options parameters.
      # parameters :
      # - options : additional parameters to support how the consumer driver works, for example : { group: 'group-1', consumer: 'consumer-1' }.
      def fetch_group_and_consumer(options:)
        group = options[:group]
        consumer = options[:consumer]
        raise ArgumentError, "Key parameter with 'group' or 'consumer' name is mandatory." if !group || !consumer

        [ group, consumer ]
      end

      # method description : acknowledge data in redis so that it is not sent again to the consumer.
      # parameters :
      # - topic : target 'topic' to be sent, for example : 'topic_io'.
      # - group : a mechanism that allows multiple workers (consumers) to share the workload of the same stream, for example : 'group-1'.
      # - message_id : is the unique identity of the message you just finished working on, example : '1707241234567-0'.
      def acknowledge(topic:, group:, message_id:)
        @redis.xack(topic, group, message_id)
      end

      # method description : the retry process failed, and the data was sent to dead letter.
      # parameters :
      # - dlq_topic : target 'topic' to be sent, for example : 'topic_io_dlq'.
      # - original_message_id : data id from redis stream, for example : '1707241234567-0'.
      # - original_data : data from redis stream, for example : { order_id: 'xyz-1', total_payment: 250000 }.
      # - error_message : error message failure when maximum retry has been done.
      def move_to_dlq(dlq_topic:, original_message_id:, original_data:, error_message:)
        # save the original payload, origin id, and error reason to the dlq stream.
        @redis.xadd(dlq_topic, { payload: {
          original_id: original_message_id,
          original_data: original_data.to_json,
          error: error_message,
          failed_at: Time.now.to_s
        }.to_json }, maxlen: ["~", @config.maxlen.to_i])
      end
  end
end