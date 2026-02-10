require_relative '../drivers/redis_stream'

module Pistonqueue
  module Driver
    def self.init_driver(driver:, config:)
      case driver
      when :redis_stream
        ::Pistonqueue::RedisStream.new(config: config)
      else
        raise ArgumentError, "Driver #{driver} unknown."
      end
    end
  end
end