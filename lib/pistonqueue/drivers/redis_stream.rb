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

      @redis.xadd(topic, { payload: data.to_json })
    end

    # method description : fetch data from redis stream and process the data with high concurrency.
    # parameters :
    # - topic : target 'topic' to be sent, for example : 'topic_io'.
    # - fiber_limit : maximum total fiber, for example : 500.
    # - options : additional parameters to support how the consumer driver works, for example : { group: 'group-1', consumer: 'consumer-1' }.
    def consume(topic:, fiber_limit:, options: {}, service_block:)
      group, consumer = fetch_group_and_consumer(options)

      setup_group(topic, group)

      logger.info("🚀 Consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}.")

      Async do |task|
        semaphore = Async::Semaphore.new(fiber_limit)

        loop do
          begin
            messages = @redis.xreadgroup(group, consumer, topic, '>', count: @config.redis_batch_size, block: @config.redis_block_duration) # read new messages from redis stream as part of a consumer group.
            next task.sleep(1) if messages.nil? || messages.empty?

            messages.each do |_stream, entries|
              entries.each do |id, data|
                semaphore.async do
                  payload = JSON.parse(data["payload"])
                  retry_count = payload.fetch('retry_count', 0)

                  begin
                    # tier 1: retry with exponential backoff and jitter at the consumer level.
                    ExponentialBackoffJitter.with_local_retry(max_retries: @config.max_local_retry) do
                      service_block.call(data)
                    end

                    # acknowledge the data so that it is not sent again to the consumer.
                    acknowledge(topic: topic, group: group, message_id: id)

                    logger.info("✅ [#{topic}] id: #{id} success.")
                  rescue => ex
                    error_msg = ex.message

                    if retry_count < 5
                      # tier 2: scalable retry (move to a specific topic to prevent consumers from getting stuck).
                      payload['retry_count'] = retry_count + 1
                      payload['last_error'] = error_msg
                      produce(topic: "#{topic}_retry", data: payload)

                      logger.warn("🔄 [#{topic}] failed. moved to retry topic (attempt : #{payload['retry_count']}).")
                    else
                      # tier 3: dead letter queue (permanent failure).
                      move_to_dlq(dlq_topic: "#{topic}_dlq", original_message_id: id, payload: payload, error_message: error_msg)

                      logger.error("💀 [#{topic}] max retries reached, moved to dlq.")
                    end
                    
                    # ack data in the origin queue to prevent retransmission.
                    acknowledge(topic: topic, group: group, message_id: id)
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
      def setup_group(topic, group)
        @redis.xgroup(:create, topic, group, '$', mkstream: true)
      rescue Redis::CommandError => e
        logger.warn("Group #{group} is already in topic [#{topic}].")
      end

      # method description : take 'group' and 'consumer' data from options parameters.
      # parameters :
      # - options : additional parameters to support how the consumer driver works, for example : { group: 'group-1', consumer: 'consumer-1' }.
      def fetch_group_and_consumer(options)
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
      # - payload : data from redis stream, for example : { order_id: 'xyz-1', total_payment: 250000 }.
      # - error_message : error message failure when maximum retry has been done.
      def move_to_dlq(dlq_topic:, original_message_id:, payload:, error_message:)
        # save the original payload, origin id, and error reason to the dlq stream.
        @redis.xadd(dlq_topic, {
          original_id: original_message_id,
          payload: payload.to_json,
          error: error_message,
          failed_at: Time.now.to_s
        })
      end
  end

  class RetryRedisStream < ::Pistonqueue::RedisStream
    def consume(topic:, fiber_limit:, options: {}, service_block:)
      
    end
  end
end