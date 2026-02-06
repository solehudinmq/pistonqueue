# frozen_string_literal: true

require_relative "pistonqueue/version"
require_relative "pistonqueue/utils/driver"

module Pistonqueue
  class Producer
    # method description : driver initialization.
    # parameters :
    # - driver : selected producer mechanism, for example : :redis_stream.
    # how to use :
    #   producer = Pistonqueue::Producer.new(driver: :redis_stream)
    def initialize(driver:)
      @driver = Pistonqueue::Driver.init_driver(driver: driver)
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
    FIBER_PROFILE = { 
      :io_bound_light => (ENV['IO_LIGHT_FIBER'] || 500).to_i, # suitable for the task : cache / logging.
      :io_bound_medium => (ENV['IO_MEDIUM_FIBER'] || 100).to_i, # suitable for the task : api call / query database.
      :io_bound_heavy => (ENV['IO_HEAVY_FIBER'] || 10).to_i, # suitable for the task : upload file / web scraping.
      :cpu_bound => (ENV['CPU_FIBER'] || 1).to_i # suitable for the task : encryption / compression / image processing.
    }.freeze

    # method description : driver initialization.
    # parameters :
    # - driver : selected consumer mechanism, for example : :redis_stream.
    # how to use :
    #   consumer = Pistonqueue::Consumer.new(driver: :redis_stream)
    def initialize(driver:)
      @driver = Pistonqueue::Driver.init_driver(driver: driver)
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

      @driver.consume(topic: topic, fiber_limit: fiber_limit, options: options, service_block: service_block)
    end

    private
      # method description : determine the number of fibers based on 'task_type'.
      def fetch_fiber_limit(task_type)
        FIBER_PROFILE.fetch(task_type)
      rescue KeyError
        raise ArgumentError, "Unknown task_type: :#{task_type}. Available types are: #{FIBER_PROFILE.keys}."
      end
  end
end
