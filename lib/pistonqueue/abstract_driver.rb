module Pistonqueue
  class AbstractDriver
    def produce(topic:, data:) raise NotImplementedError end
    def consume(topic:, fiber_limit:, options: {}) raise NotImplementedError end
  end
end