# frozen_string_literal: true

require_relative "pistonqueue/version"
require_relative "pistonqueue/utils/driver"
require_relative "pistonqueue/configuration"

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

  # fetch env data.
  CONFIG = Pistonqueue.configuration

  class Producer
    # method description : driver initialization.
    # parameters :
    # - driver : selected producer mechanism, for example : :redis_stream.
    # - config : env value settings from client.
    # how to use :
    #   producer = Pistonqueue::Producer.new(driver: :redis_stream, config: Pistonqueue.configuration)
    def initialize(driver:)
      @driver = Pistonqueue::Driver.init_driver(driver: driver, config: CONFIG)
    end

    # method description : send data to the 'topic'.
    # parameters :
    # - topic : target 'topic' to be sent.
    # - data : data object that will be sent to the topic.
    # how to use :
    #   producer.publish(topic: 'topic_io', data: { order_id: 'xyz-1', total_payment: 250000 })
    def publish(topic:, data:)
      @driver.produce(topic: topic, data: data)
    end
  end

  class Consumer
    # method description : driver initialization.
    # parameters :
    # - driver : selected consumer mechanism, for example : :redis_stream.
    # - config : env value settings from client.
    # how to use :
    #   consumer = Pistonqueue::Consumer.new(driver: :redis_stream, config: Pistonqueue.configuration)
    def initialize(driver:)
      @driver = Pistonqueue::Driver.init_driver(driver: driver, config: CONFIG)
    end

    # method description : receive data from topics, and process it with concurrency based on task type.
    # parameters :
    # - topic : target 'topic' to be sent.
    # - task_type : 'task_type' to determine how to handle concurrency, for example : :io_bound_light / :io_bound_medium / :io_bound_heavy / :cpu_bound.
    # - **options : additional parameters to support how the consumer driver works.
    # how to use :
    # consumer.subscribe(topic: 'topic_io', task_type: :io_bound_heavy, group: 'group-1', consumer: 'consumer-1') do |data|
    #   # your logic here
    # end
    def subscribe(topic:, task_type: :io_bound_medium, **options, &service_block)
      fiber_limit = fetch_fiber_limit(task_type)
      is_retry = options[:is_retry] || false
      @driver.consume(topic: topic, fiber_limit: fiber_limit, is_retry: is_retry, options: options, service_block: service_block)
    end

    private
      # method description : determine the number of fibers based on 'task_type'.
      # parameters :
      # - task_type : the type of task that will be performed by the consumer.
      def fetch_fiber_limit(task_type)
        fiber_profile.fetch(task_type)
      rescue KeyError
        raise ArgumentError, "Unknown task_type: :#{task_type}. Available types are: #{fiber_profile.keys}."
      end

      # method description : mapping the number of fibers based on the type of task.
      def fiber_profile
        { 
          :io_bound_light => CONFIG.io_light_fiber.to_i, # suitable for the task : cache / logging.
          :io_bound_medium => CONFIG.io_medium_fiber.to_i, # suitable for the task : api call / query database.
          :io_bound_heavy => CONFIG.io_heavy_fiber.to_i, # suitable for the task : upload file / web scraping.
          :cpu_bound => CONFIG.cpu_fiber.to_i # suitable for the task : encryption / compression / image processing.
        }
      end
  end

  class DeadLetter
    # method description : driver initialization.
    # parameters :
    # - driver : selected dead letter mechanism, for example : :redis_stream.
    # - config : env value settings from client.
    # how to use :
    #   dead_letter = Pistonqueue::DeadLetter.new(driver: :redis_stream, config: Pistonqueue.configuration)
    def initialize(driver:)
      @driver = Pistonqueue::Driver.init_driver(driver: driver, config: CONFIG)
    end

    # method description : receive data from topics, and process it with concurrency based on task type.
    # parameters :
    # - topic : target 'topic' to be sent.
    # - task_type : 'task_type' to determine how to handle concurrency, for example : :io_bound_light / :io_bound_medium / :io_bound_heavy / :cpu_bound.
    # - **options : additional parameters to support how the consumer driver works.
    # how to use :
    # dead_letter.subscribe(topic: 'topic_io', task_type: :io_bound_heavy, group: 'group-1', consumer: 'consumer-1') do |data|
    #   # your logic here
    # end
    def subscribe(topic:, task_type: :io_bound_medium, **options, &service_block)
      fiber_limit = fetch_fiber_limit(task_type)
      @driver.dead_letter(topic: topic, fiber_limit: fiber_limit, options: options, service_block: service_block)
    end

    private
      # method description : determine the number of fibers based on 'task_type'.
      # parameters :
      # - task_type : the type of task that will be performed by the consumer.
      def fetch_fiber_limit(task_type)
        fiber_profile.fetch(task_type)
      rescue KeyError
        raise ArgumentError, "Unknown task_type: :#{task_type}. Available types are: #{fiber_profile.keys}."
      end

      # method description : mapping the number of fibers based on the type of task.
      def fiber_profile
        { 
          :io_bound_light => CONFIG.io_light_fiber.to_i, # suitable for the task : cache / logging.
          :io_bound_medium => CONFIG.io_medium_fiber.to_i, # suitable for the task : api call / query database.
          :io_bound_heavy => CONFIG.io_heavy_fiber.to_i, # suitable for the task : upload file / web scraping.
          :cpu_bound => CONFIG.cpu_fiber.to_i # suitable for the task : encryption / compression / image processing.
        }
      end
  end
end
