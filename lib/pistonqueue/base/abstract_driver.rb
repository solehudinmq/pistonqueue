module Pistonqueue
  class AbstractDriver
    def produce(topic:, data: {}) raise NotImplementedError end
    def consume(topic:, fiber_limit:, is_retry: false, is_stop: false, options: {}, &execution_block) raise NotImplementedError end
    def dead_letter(topic:, fiber_limit:, is_archive: false, is_stop: false, options: {}, &execution_block) raise NotImplementedError end
    def reclaim(topic:, fiber_limit:, is_retry: false, is_stop: false, options: {}, &execution_block) raise NotImplementedError end
    def dead_letter_reclaim(topic:, fiber_limit:, is_stop: false, options: {}, &execution_block) raise NotImplementedError end
  end
end