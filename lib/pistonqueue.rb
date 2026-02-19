# frozen_string_literal: true

require_relative "pistonqueue/version"
require_relative "pistonqueue/driver"
require_relative "pistonqueue/configuration"
require_relative "pistonqueue/utils/unit_execution"
require_relative "pistonqueue/utils/request_validator"

module Pistonqueue
  class << self
    # method description : method to retrieve the env value.
    def configuration
      @configuration ||= Pistonqueue::Configuration.new
    end

    # method description : method to set the value of env.
    # how to use :
      # Pistonqueue.configure do |config|
      #   config.io_light_fiber = ENV['IO_LIGHT_FIBER']
      #   config.io_medium_fiber = ENV['IO_MEDIUM_FIBER']
      #   config.io_heavy_fiber = ENV['IO_HEAVY_FIBER']
      #   config.cpu_fiber = ENV['CPU_FIBER']
      #   config.redis_url = ENV['REDIS_URL']
      #   config.redis_block_duration = ENV['REDIS_BLOCK_DURATION']
      #   config.redis_batch_size = ENV['REDIS_BATCH_SIZE']
      #   config.max_local_retry = ENV['MAX_LOCAL_RETRY']
      #   config.max_retry = ENV['MAX_RETRY']
      #   config.maxlen = ENV['MAXLEN']
      #   config.connection_pool_size = ENV['CONNECTION_POOL_SIZE']
      #   config.connection_timeout = ENV['CONNECTION_TIMEOUT']
      # end
    def configure
      yield(configuration)
    end
  end

  class Producer
    include Pistonqueue::Driver

    # method description : driver initialization.
    # parameters :
    # - driver : selected producer mechanism, for example : :redis_stream.
    # how to use :
    #   producer = Pistonqueue::Producer.new(driver: :redis_stream, config: Pistonqueue.configuration)
    def initialize(driver:)
      @driver = init_driver(driver: driver, config: Pistonqueue.configuration)
    end

    # method description : send data to the 'topic'.
    # parameters :
    # - topic : target 'topic' to be sent.
    # - data : data object that will be sent to the topic.
    # how to use :
    #   producer.perform(topic: 'topic_io', data: { order_id: 'xyz-1', total_payment: 250000 })
    def perform(topic:, data:)
      @driver.produce(topic: topic, data: data)
    end
  end

  class Consumer
    include Pistonqueue::Driver
    include Pistonqueue::UnitExecution
    include Pistonqueue::RequestValidator

    # method description : driver initialization.
    # parameters :
    # - driver : selected consumer mechanism, for example : :redis_stream.
    # how to use :
    #   consumer = Pistonqueue::Consumer.new(driver: :redis_stream)
    def initialize(driver:)
      @config = Pistonqueue.configuration
      @driver = init_driver(driver: driver, config: @config)
    end

    # method description : receive data from topics, and process it with concurrency based on task type.
    # parameters :
    # - topic : target 'topic' to be sent.
    # - task_type : 'task_type' to determine how to handle concurrency, for example : :io_bound_light / :io_bound_medium / :io_bound_heavy / :cpu_bound.
    # - **options : additional parameters to support how the consumer driver works.
    # - &service_block : explicit block parameter.
    # how to use :
    # consumer.perform(topic: 'topic_io', task_type: :io_bound_heavy, group: 'group-1', consumer: 'consumer-1') do |data|
    #   # your logic here
    # end
    def perform(topic:, task_type: :io_bound_medium, **options, &service_block)
      @driver.consume(
        topic: topic, 
        fiber_limit: fetch_fiber_limit(config: @config, task_type: task_type), 
        is_retry: enabled?(parameter_name: 'is_retry', value: options[:is_retry] || false), 
        is_stop: enabled?(parameter_name: 'is_stop', value: options[:is_stop] || false),
        options: options
      ) do |payload|
        service_block.call(payload)
      end
    end
  end

  class DlqConsumer
    include Pistonqueue::Driver
    include Pistonqueue::UnitExecution
    include Pistonqueue::RequestValidator

    # method description : driver initialization.
    # parameters :
    # - driver : selected dead letter mechanism, for example : :redis_stream.
    # how to use :
    #   dlq_consumer = Pistonqueue::DlqConsumer.new(driver: :redis_stream)
    def initialize(driver:)
      @config = Pistonqueue.configuration
      @driver = init_driver(driver: driver, config: @config)
    end

    # method description : receive data from topics, and process it with concurrency based on task type.
    # parameters :
    # - topic : target 'topic' to be sent.
    # - task_type : 'task_type' to determine how to handle concurrency, for example : :io_bound_light / :io_bound_medium / :io_bound_heavy / :cpu_bound.
    # - **options : additional parameters to support how the consumer driver works.
    # - &service_block : explicit block parameter.
    # how to use :
    # dlq_consumer.perform(topic: 'topic_io', task_type: :io_bound_heavy, group: 'group-1', consumer: 'consumer-1') do |data|
    #   # your logic here
    # end
    def perform(topic:, task_type: :io_bound_medium, **options, &service_block)
      @driver.dead_letter(
        topic: topic, 
        fiber_limit: fetch_fiber_limit(config: @config, task_type: task_type), 
        is_archive: enabled?(parameter_name: 'is_archive', value: options[:is_archive] || false), 
        is_stop: enabled?(parameter_name: 'is_stop', value: options[:is_stop] || false),
        options: options
      ) do |original_id, original_data, err_msg, failed_at|
        service_block.call(original_id, original_data, err_msg, failed_at)
      end
    end
  end

  class RecoveryConsumer
    include Pistonqueue::Driver
    include Pistonqueue::UnitExecution
    include Pistonqueue::RequestValidator

    # method description : driver initialization.
    # parameters :
    # - driver : selected recovery mechanism, for example : :redis_stream.
    # how to use :
    #   recovery_consumer = Pistonqueue::RecoveryConsumer.new(driver: :redis_stream)
    def initialize(driver:)
      @config = Pistonqueue.configuration
      @driver = init_driver(driver: driver, config: @config)
    end

    # method description : receive the main / retry data that is stuck, and process it with concurrency.
    # parameters :
    # - topic : target 'topic' to be sent.
    # - task_type : 'task_type' to determine how to handle concurrency, for example : :io_bound_light / :io_bound_medium / :io_bound_heavy / :cpu_bound.
    # - **options : additional parameters to support how the consumer driver works.
    # - &service_block : explicit block parameter.
    # how to use :
    # recovery_consumer.perform(topic: 'topic_io', task_type: :io_bound_heavy, group: 'group-1', consumer: 'consumer-1') do |data|
    #   # your logic here
    # end
    def perform(topic:, task_type: :io_bound_medium, **options, &service_block)
      @driver.reclaim(
        topic: topic, 
        fiber_limit: fetch_fiber_limit(config: @config, task_type: task_type), 
        is_retry: enabled?(parameter_name: 'is_retry', value: options[:is_retry] || false),
        is_stop: enabled?(parameter_name: 'is_stop', value: options[:is_stop] || false),
        options: options
      ) do |payload|
        service_block.call(payload)
      end
    end

    # method description : receive the dead letter data that is stuck, and process it with concurrency.
    # parameters :
    # - topic : target 'topic' to be sent.
    # - task_type : 'task_type' to determine how to handle concurrency, for example : :io_bound_light / :io_bound_medium / :io_bound_heavy / :cpu_bound.
    # - **options : additional parameters to support how the consumer driver works.
    # - &service_block : explicit block parameter.
    # how to use :
    # recovery_consumer.dead_letter_perform(topic: 'topic_io', task_type: :io_bound_heavy, group: 'group-1', consumer: 'consumer-1') do |data|
    #   # your logic here
    # end
    def dead_letter_perform(topic:, task_type: :io_bound_medium, **options, &service_block)
      @driver.dead_letter_reclaim(
        topic: topic, 
        fiber_limit: fetch_fiber_limit(config: @config, task_type: task_type), 
        is_stop: enabled?(parameter_name: 'is_stop', value: options[:is_stop] || false),
        options: options
      ) do |original_id, original_data, err_msg, failed_at|
        service_block.call(original_id, original_data, err_msg, failed_at)
      end
    end
  end
end
