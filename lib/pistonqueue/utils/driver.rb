require_relative '../drivers/redis_stream'

module Pistonqueue
  module Driver
    def self.init_driver(driver:)
      case driver
      when :redis_stream
        ::Pistonqueue::RedisStream.new
      else
        raise ArgumentError, "Driver #{driver} unknown."
      end
    end
  end
end