require 'redis'
require 'connection_pool'
require 'async'
require 'async/semaphore'
require 'json'

require_relative '../base/abstract_driver'
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
    # - is_stop : make sure the value is always 'false' when running in production, because this is only used to stop unit tests, for example : false / true.
    # - options : additional parameters to support how the consumer driver works, for example : { group: 'group-1', consumer: 'consumer-1' }.
    def consume(topic:, fiber_limit:, is_retry: false, is_stop: false, options: {}, &execution_block)
      group, consumer = fetch_group_and_consumer(options: options)

      log_message = "🚀 main consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}."
      sleep_time = 1
      if is_retry
        topic = "#{topic}_retry"
        sleep_time = 5
        log_message = "🚀 retry consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}."
      end

      logger.info(log_message)

      execute(topic: topic, group: group, consumer: consumer, fiber_limit: fiber_limit, sleep_time: sleep_time, is_stop: is_stop, type: :regular) do |message_id, payload|
        if is_retry
          retry_process_consumer(topic: topic, message_id: message_id, payload: payload) do |data|
            execution_block.call(data)
          end
        else
          main_process_consumer(topic: topic, message_id: message_id, payload: payload) do |data|
            execution_block.call(data)
          end
        end
      end
    end

    # method description : fetch data from redis stream and process dead letter data with high concurrency.
    # parameters :
    # - topic : target 'topic' to be sent, for example : 'topic_io'.
    # - fiber_limit : maximum total fiber, for example : 500.
    # - is_archive : consumer dead letter that still fails in the process do the process manually, for example : true / false.
    # - is_stop : make sure the value is always 'false' when running in production, because this is only used to stop unit tests, for example : false / true.
    # - options : additional parameters to support how the consumer driver works, for example : { group: 'group-2', consumer: 'consumer-2' }.
    def dead_letter(topic:, fiber_limit:, is_archive: false, is_stop: false, options: {}, &execution_block)
      group, consumer = fetch_group_and_consumer(options: options)

      topic = "#{topic}_dlq"
      log_message = "🚀 dead_letter consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}."

      if is_archive
        topic = "#{topic}_archive"
        log_message = "🚀 dead_letter_archive consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}."
      end

      logger.info(log_message)

      execute(topic: topic, group: group, consumer: consumer, fiber_limit: fiber_limit, sleep_time: 5, is_stop: is_stop, type: :dead_letter) do |message_id, original_id, original_data, err_msg, failed_at|
        if is_archive
          dead_letter_archive_process_consumer(topic: topic, message_id: message_id, original_id: original_id, original_data: original_data, err_msg: err_msg, failed_at: failed_at) do |id, data, err, err_at|
            execution_block.call(id, data, err, err_at)
          end
        else
          dead_letter_process_consumer(topic: topic, message_id: message_id, original_id: original_id, original_data: original_data, err_msg: err_msg, failed_at: failed_at) do |id, data, err, err_at|
            execution_block.call(id, data, err, err_at)
          end
        end
      end
    end

    # method description : fetch main stuck data from redis stream and process data with high concurrency.
    # parameters :
    # - topic : target 'topic' to be sent, for example : 'topic_io'.
    # - fiber_limit : maximum total fiber, for example : 500.
    # - is_retry : the consumer will run the retry process, for example : true / false.
    # - is_stop : make sure the value is always 'false' when running in production, because this is only used to stop unit tests, for example : false / true.
    # - options : additional parameters to support how the consumer driver works, for example : { group: 'group-1', consumer: 'consumer-1' }.
    def reclaim(topic:, fiber_limit:, is_retry: false, is_stop: false, options: {}, &execution_block)
      group, consumer = fetch_group_and_consumer(options: options)

      log_message = "🚀 reclaim main consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}."
      if is_retry
        topic = "#{topic}_retry"
        log_message = "🚀 reclaim retry consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}."
      end

      logger.info(log_message)

      recover_pending_message(topic: topic, group: group, consumer: consumer, fiber_limit: fiber_limit, type: :regular, is_stop: is_stop) do |message_id, payload|
        if is_retry
          retry_process_consumer(topic: topic, message_id: message_id, payload: payload) do |data_payload|
            execution_block.call(data_payload)
          end
        else
          main_process_consumer(topic: topic, message_id: message_id, payload: payload) do |data_payload|
            execution_block.call(data_payload)
          end
        end
      end
    end

    # method description : fetch dead letter stuck data from redis stream and process data with high concurrency.
    # parameters :
    # - topic : target 'topic' to be sent, for example : 'topic_io'.
    # - fiber_limit : maximum total fiber, for example : 500.
    # - is_stop : make sure the value is always 'false' when running in production, because this is only used to stop unit tests, for example : false / true.
    # - options : additional parameters to support how the consumer driver works, for example : { group: 'group-1', consumer: 'consumer-1' }.
    def dead_letter_reclaim(topic:, fiber_limit:, is_stop: false, options: {}, &execution_block)
      group, consumer = fetch_group_and_consumer(options: options)

      topic = "#{topic}_dlq"

      logger.info("🚀 dead letter reclaim consumer #{consumer} started on topic [#{topic}], with fiber limit : #{fiber_limit}.")

      recover_pending_message(topic: topic, group: group, consumer: consumer, fiber_limit: fiber_limit, type: :dead_letter, is_stop: is_stop) do |message_id, original_id, original_data, err_msg, failed_at|
        dead_letter_process_consumer(topic: topic, message_id: message_id, original_id: original_id, original_data: original_data, err_msg: err_msg, failed_at: failed_at) do |id, data, err, err_at|
          execution_block.call(id, data, err, err_at)
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
            original_data: original_data,
            error: error_message,
            failed_at: Time.now.to_s
          }.to_json }, maxlen: ["~", @config.maxlen.to_i])
        end
      end

      # method description : running business logic for consumers.
      # parameters :
      # - topic : target 'topic' to be sent, for example : 'topic_io'.
      # - group : a mechanism that allows multiple workers (consumers) to share the workload of the same stream, for example : 'group-1'.
      # - consumer : specific name for each instance of your consumer application, for example : 'consumer-1'.
      # - fiber_limit : fiber_limit : maximum total fiber, for example : 500.
      # - sleep_time : in the context of your application's loop, sleep_time serves as a back-off to prevent the application from blindly polling redis when there is no new data, for example : 3.
      # - type : the type of consumer logic that is executed, for example : :regular / :dead_letter.
      # - special_id : special symbols to provide certain logical instructions to redis, for example : '>' / '0' / '$'
      # - is_stop : make sure the value is always 'false' when running in production, because this is only used to stop unit tests, for example : false / true.
      def execute(topic:, group:, consumer:, fiber_limit:, sleep_time:, type:, special_id: '>', is_stop: false, &execution_block)
        raise ArgumentError, "Parameter 'type' #{type} is wrong." unless [:regular, :dead_letter].include?(type)

        setup_group(topic: topic, group: group)

        Async do |task|
          semaphore = Async::Semaphore.new(fiber_limit)

          loop do
            begin
              messages = @redis_pool.with do |conn|
                conn.xreadgroup(group, consumer, topic, special_id, count: @config.redis_batch_size.to_i, block: @config.redis_block_duration.to_i) # read new messages from redis stream as part of a consumer group.
              end

              next task.sleep(sleep_time) if messages.nil? || messages.empty?

              messages.each do |_stream, entries|
                entries.each do |id, data|
                  semaphore.async do
                    payload = JSON.parse(data["payload"])

                    if type == :dead_letter
                      execution_block.call(id, payload["original_id"], payload['original_data'], payload['error'], payload['failed_at'])
                    else
                      execution_block.call(id, payload)
                    end

                    # acknowledge the data so that it is not sent again to the consumer.
                    acknowledge(topic: topic, group: group, message_id: id)
                  end
                end
              end
            rescue => e
              logger.error("#{type} consumer #{consumer} on topic [#{topic}] error : #{e.message}.")
            end

            break if is_stop
          end
        end
      end

      # method description : running business logic for retry consumers.
      # parameters :
      # - topic : target 'topic' to be sent, for example : 'topic_io'.
      # - message_id : is the unique identity of the message you just finished working on, example : '1707241234567-0'.
      # - payload : data from redis stream, for example : { order_id: 'xyz-1', total_payment: 250000 }.
      def retry_process_consumer(topic:, message_id:, payload:, &execution_block)
        max_retry = @config.max_retry.to_i

        begin
          # tier 2: exponential backoff retry process with jitter outside the main consumer.
          retry_with_exponential_backoff_jitter(max_retries: max_retry) do
            execution_block.call(payload)
          end

          logger.info("✅ retry consumer with [#{topic}] id: #{message_id} success.")
        rescue => ex
          error_msg = ex.message
          previous_topic = topic.sub('_retry', '')

          # tier 3: dead letter queue (permanent failure).
          move_to_dlq(dlq_topic: "#{previous_topic}_dlq", original_message_id: message_id, original_data: payload.to_json, error_message: error_msg)
          
          logger.error("💀 retry consumer with [#{previous_topic}] max retries reached, moved to #{previous_topic}_dlq topic.")
        end
      end

      # method description : running business logic for main consumers.
      # parameters :
      # - topic : target 'topic' to be sent, for example : 'topic_io'.
      # - message_id : is the unique identity of the message you just finished working on, example : '1707241234567-0'.
      # - payload : data from redis stream, for example : { order_id: 'xyz-1', total_payment: 250000 }.
      def main_process_consumer(topic:, message_id:, payload:, &execution_block)
        max_local_retry = @config.max_local_retry.to_i
        total_trials = 0

        begin
          # tier 1: retry with exponential backoff and jitter at the consumer level.
          retry_with_exponential_backoff_jitter(max_retries: max_local_retry) do
            total_trials += 1
            execution_block.call(payload)
          end

          logger.info("✅ main consumer with [#{topic}] id: #{message_id} success.")
        rescue => ex
          # do a retry outside the consumer.
          produce(topic: "#{topic}_retry", data: payload)

          logger.warn("🔄 main consumer with [#{topic}] failed. moved to #{topic}_retry topic (total trials : #{total_trials}).")
        end
      end

      # method description : running business logic for dead letter consumers.
      # parameters :
      # - topic : target 'topic' to be sent, for example : 'topic_io'.
      # - message_id : is the unique identity of the message you just finished working on, example : '1707241234567-0'.
      # - original_id : message id of the previous failed retry process, example : '1707241234578-0'.
      # - original_data : data from a previously failed retry process, for example : "{\"order_id\":\"xyz-1\",\"total_payment\":250000}".
      # - err_msg : error message from a previously failed retry process, for example : 'no implicit conversion of Symbol into Integer (TypeError)'.
      # - failed_at : failure time of the previous failed retry process, for example : '2026-02-16 19:43:13 +0700'.
      def dead_letter_process_consumer(topic:, message_id:, original_id:, original_data:, err_msg:, failed_at:, &execution_block)
        begin
          retry_with_exponential_backoff_jitter(max_retries: 1) do
            execution_block.call(original_id, original_data, err_msg, failed_at)
          end

          logger.info("✅ dead_letter [#{topic}] id: #{message_id} success.")
        rescue => ex
          error_msg = ex.message
          previous_topic = topic.sub('_dlq', '')

          logger.error("💀 dead_letter [#{topic}] max retries reached, moved to #{previous_topic}_dlq_archive topic.")

          move_to_dlq(dlq_topic: "#{previous_topic}_dlq_archive", original_message_id: message_id, original_data: original_data, error_message: error_msg)
        end
      end

      # method description : running business logic for dead letter archive consumers.
      # parameters :
      # - topic : target 'topic' to be sent, for example : 'topic_io'.
      # - message_id : is the unique identity of the message you just finished working on, example : '1707241234567-0'.
      # - original_id : message id of the previous failed retry process, example : '1707241234578-0'.
      # - original_data : data from a previously failed retry process, for example : "{\"order_id\":\"xyz-1\",\"total_payment\":250000}".
      # - err_msg : error message from a previously failed retry process, for example : 'no implicit conversion of Symbol into Integer (TypeError)'.
      # - failed_at : failure time of the previous failed retry process, for example : '2026-02-16 19:43:13 +0700'.
      def dead_letter_archive_process_consumer(topic:, message_id:, original_id:, original_data:, err_msg:, failed_at:, &execution_block)
        begin
          execution_block.call(original_id, original_data, err_msg, failed_at)

          logger.info("✅ dead_letter_archive [#{topic}] id: #{message_id} success.")
        rescue => ex
          logger.error("💀 dead_letter_archive [#{topic}] failed to process.")
        end
      end

      # method description : running business logic for the implicated data.
      # parameters :
      # - topic : target 'topic' to be sent, for example : 'topic_io'.
      # - group : a mechanism that allows multiple workers (consumers) to share the workload of the same stream, for example : 'group-1'.
      # - consumer : specific name for each instance of your consumer application, for example : 'consumer-1'.
      # - fiber_limit : fiber_limit : maximum total fiber, for example : 500.
      # - type : the type of consumer logic that is executed, for example : :regular / :dead_letter.
      # - is_stop : make sure the value is always 'false' when running in production, because this is only used to stop unit tests, for example : false / true.
      def recover_pending_message(topic:, group:, consumer:, fiber_limit:, type:, is_stop:, &execution_block)
        raise ArgumentError, "Parameter 'type' #{type} is wrong." unless [:regular, :dead_letter].include?(type)

        setup_group(topic: topic, group: group)

        Async do |task|
          semaphore = Async::Semaphore.new(fiber_limit)

          loop do
            begin
              messages = @redis_pool.with do |conn|
                conn.xautoclaim(topic, group, consumer, @config.redis_min_idle_time.to_i, '0-0', count: @config.redis_batch_size.to_i) # read stuck messages from redis stream as part of a consumer group.
              end
              
              next task.sleep(5) if messages.nil? || messages.empty?

              result = messages["entries"] || []

              if result.any?
                result.each do |id, data|
                  semaphore.async do
                    payload = JSON.parse(data["payload"])
                    
                    if type == :dead_letter
                      execution_block.call(id, payload["original_id"], payload['original_data'], payload['error'], payload['failed_at'])
                    else
                      execution_block.call(id, payload)
                    end

                    # acknowledge the data so that it is not sent again to the consumer.
                    acknowledge(topic: topic, group: group, message_id: id)
                  end
                end
              end
            rescue => e
              logger.error("reclaim consumer #{consumer} on topic [#{topic}] error : #{e.message}.")
            end

            break if is_stop
          end
        end
      end
  end
end