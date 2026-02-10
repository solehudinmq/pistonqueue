module Pistonqueue
  class Configuration
    attr_accessor :io_light_fiber, :io_medium_fiber, :io_heavy_fiber, :cpu_fiber, :redis_url, :redis_block_duration, :redis_batch_size, :max_local_retry

    def initialize
      @io_light_fiber = 500
      @io_medium_fiber = 100
      @io_heavy_fiber = 10
      @cpu_fiber = 1
      @redis_url = 'redis://127.0.0.1:6379'
      @redis_block_duration = 2000 # determines how long (in milliseconds) redis should wait if it finds that there are no new messages at that time.
      @redis_batch_size = 10 # the maximum number of messages to be retrieved in one command in redis.
      @max_local_retry = 1 # maximum number of retries can be made at the consumer.
    end
  end
end