require 'redis'
require 'connection_pool'
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

      @redis_pool = ConnectionPool.new(size: @config.connection_pool_size.to_i, timeout: @config.connection_timeout.to_i) do
        Redis.new(url: @config.redis_url)
      end
    end

    # method description : add new data into redis stream.
    # parameters :
    # - topic : target 'topic' to be sent, for example : 'topic_io'.
    # - data : data object that will be sent to the topic, for example : { order_id: 'xyz-1', total_payment: 250000 }.
    def produce(topic:, data: {})
      raise ArgumentError, "The 'data' parameter value must contain an object." if !(data.is_a?(Hash) && data.any?)
      
      @redis_pool.with do |conn|
        conn.xadd(topic, { payload: data.to_json }, maxlen: ["~", @config.maxlen.to_i])
      end
    end

    # method description : fetch data from redis stream and process the data with high concurrency.
    # parameters :
    # - topic : target 'topic' to be sent, for example : 'topic_io'.
    # - fiber_limit : maximum total fiber, for example : 500.
    # - is_retry : the consumer will run the retry process, for example : true / false.
    # - options : additional parameters to support how the consumer driver works, for example : { group: 'group-1', consumer: 'consumer-1' }.
    def consume(topic:, fiber_limit:, is_retry: false, options: {}, service_block:)
      group, consumer = fetch_group_and_consumer(options: options)

      sleep_time = 1
      consumer_log = "🚀 Main consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}."
      if is_retry
        topic = "#{topic}_retry"
        sleep_time = 5
        consumer_log = "🚀 Retry consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}."
      end

      logger.info(consumer_log)

      setup_group(topic: topic, group: group)

      Async do |task|
        semaphore = Async::Semaphore.new(fiber_limit)

        loop do
          begin
            messages = @redis_pool.with do |conn|
              conn.xreadgroup(group, consumer, topic, '>', count: @config.redis_batch_size.to_i, block: @config.redis_block_duration.to_i) # read new messages from redis stream as part of a consumer group.
            end

            next task.sleep(sleep_time) if messages.nil? || messages.empty?

            messages.each do |_stream, entries|
              entries.each do |id, data|
                semaphore.async do
                  payload = JSON.parse(data["payload"])

                  if is_retry # retry process with job.
                    max_retry = @config.max_retry.to_i

                    begin
                      # tier 2: exponential backoff retry process with jitter outside the main consumer.
                      ExponentialBackoffJitter.with_retry(max_retries: max_retry) do
                        service_block.call(payload)
                      end

                      logger.info("✅ Retry consumer with [#{topic}] id: #{id} success.")
                    rescue => ex
                      error_msg = ex.message
                      previous_topic = topic.sub('_retry', '')

                      # tier 3: dead letter queue (permanent failure).
                      move_to_dlq(dlq_topic: "#{previous_topic}_dlq", original_message_id: id, original_data: payload, error_message: error_msg)
                      
                      logger.error("💀 Retry consumer with [#{previous_topic}] max retries reached, moved to #{previous_topic}_dlq topic.")
                    end
                  else # main process.
                    max_local_retry = @config.max_local_retry.to_i
                    total_trials = 0

                    begin
                      # tier 1: retry with exponential backoff and jitter at the consumer level.
                      ExponentialBackoffJitter.with_retry(max_retries: max_local_retry) do
                        total_trials += 1
                        service_block.call(payload)
                      end

                      logger.info("✅ Main consumer with [#{topic}] id: #{id} success.")
                    rescue => ex
                      # do a retry outside the consumer.
                      produce(topic: "#{topic}_retry", data: payload)

                      logger.warn("🔄 Main consumer with [#{topic}] failed. moved to #{topic}_retry topic (total trials : #{total_trials}).")
                    end
                  end

                  # acknowledge the data so that it is not sent again to the consumer.
                  acknowledge(topic: topic, group: group, message_id: id)
                end
              end
            end
          rescue => e
            log_err = is_retry ? "Retry consumer #{consumer} on topic [#{topic}] error : #{e.message}." : "Main consumer #{consumer} on topic [#{topic}] error : #{e.message}."

            logger.error(log_err)
          end

          break if options[:is_stop]
        end
      end
    end

    # method description : fetch data from redis stream and process dead letter data.
    # parameters :
    # - topic : target 'topic' to be sent, for example : 'topic_io'.
    # - fiber_limit : maximum total fiber, for example : 500.
    # - is_archive : consumer dead letter that still fails in the process do the process manually, for example : true / false.
    # - options : additional parameters to support how the consumer driver works, for example : { group: 'group-2', consumer: 'consumer-2' }.
    def dead_letter(topic:, fiber_limit:, is_archive: false, options: {}, service_block:)
      group, consumer = fetch_group_and_consumer(options: options)

      topic = "#{topic}_dlq"
      dead_letter_log = "🚀 Dead letter consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}."
      if is_archive
        topic = "#{topic}_archive"
        dead_letter_log = "🚀 Dead letter archive consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}."
      end

      logger.info(dead_letter_log)

      setup_group(topic: topic, group: group)

      sleep_time = 5

      Async do |task|
        semaphore = Async::Semaphore.new(fiber_limit)

        loop do
          begin
            messages = @redis_pool.with do |conn|
              conn.xreadgroup(group, consumer, topic, '>', count: @config.redis_batch_size.to_i, block: @config.redis_block_duration.to_i) # read new messages from redis stream as part of a consumer group.
            end

            next task.sleep(sleep_time) if messages.nil? || messages.empty?

            messages.each do |_stream, entries|
              entries.each do |id, data|
                semaphore.async do
                  payload = JSON.parse(data["payload"])

                  if is_archive
                    begin
                      service_block.call(payload["original_id"], payload['original_data'], payload['error'], payload['failed_at'])

                      logger.info("✅ Dead letter archive [#{topic}] id: #{id} success.")
                    rescue => ex
                      logger.error("💀 Dead letter archive [#{topic}] failed to process.")
                    end
                  else
                    max_retry = @config.max_retry.to_i

                    begin
                      ExponentialBackoffJitter.with_retry(max_retries: max_retry) do
                        service_block.call(payload["original_id"], payload['original_data'], payload['error'], payload['failed_at'])
                      end

                      logger.info("✅ Dead letter [#{topic}] id: #{id} success.")
                    rescue => ex
                      error_msg = ex.message
                      previous_topic = topic.sub('_dlq', '')

                      logger.error("💀 Dead letter [#{topic}] max retries reached, moved to #{previous_topic}_dlq_archive topic.")

                      move_to_dlq(dlq_topic: "#{previous_topic}_dlq_archive", original_message_id: id, original_data: payload, error_message: error_msg)
                    end
                  end

                  acknowledge(topic: topic, group: group, message_id: id)
                end
              end
            end
          rescue => e
            log_err = is_archive ? "Dead letter archive consumer #{consumer} on topic [#{topic}] error : #{e.message}." : "Dead letter consumer #{consumer} on topic [#{topic}] error : #{e.message}."
            logger.error(log_err)
          end

          break if options[:is_stop]
        end
      end
    end

    private
      # method description : register consumer group to redis stream.
      # parameters :
      # - topic : target 'topic' to be sent, for example : 'topic_io'.
      # - group : a mechanism that allows multiple workers (consumers) to share the workload of the same stream, for example : 'group-1'.
      def setup_group(topic:, group:)
        @redis_pool.with do |conn|
          conn.xgroup(:create, topic, group, '$', mkstream: true)
        end

        true
      rescue Redis::CommandError => e
        if e.message.include?("BUSYGROUP")
          logger.warn("Group #{group} already exists in topic [#{topic}]. Skipping...")
          false
        else
          logger.error("Redis setup group error : #{e.message}.")
          raise e
        end
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
        @redis_pool.with do |conn|
          conn.xack(topic, group, message_id)
        end
      end

      # method description : the retry process failed, and the data was sent to dead letter.
      # parameters :
      # - dlq_topic : target 'topic' to be sent, for example : 'topic_io_dlq'.
      # - original_message_id : data id from redis stream, for example : '1707241234567-0'.
      # - original_data : data from redis stream, for example : { order_id: 'xyz-1', total_payment: 250000 }.
      # - error_message : error message failure when maximum retry has been done.
      def move_to_dlq(dlq_topic:, original_message_id:, original_data:, error_message:)
        # save the original payload, origin id, and error reason to the dlq stream.
        @redis_pool.with do |conn|
          conn.xadd(dlq_topic, { payload: {
            original_id: original_message_id,
            original_data: original_data.to_json,
            error: error_message,
            failed_at: Time.now.to_s
          }.to_json }, maxlen: ["~", @config.maxlen.to_i])
        end
      end
  end
end