module Pistonqueue
  class AbstractDriver
    def produce(topic:, data: {}) raise NotImplementedError end
    def consume(topic:, fiber_limit:, is_retry: false, options: {}, service_block:) raise NotImplementedError end
    def dead_letter(topic:, fiber_limit:, is_archive: false, options: {}, service_block:) raise NotImplementedError end
  end
end