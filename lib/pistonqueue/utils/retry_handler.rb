module Pistonqueue
  module RetryHandler
    class ExponentialBackoffJitter
      def self.calculate_backoff(retries)
        # Exponential backoff: (2^n) + jitter
        (2**retries) + rand(0.0..1.0)
      end

      def self.with_local_retry(max_retries:)
        current_retry = 0
        begin
          yield
        rescue => e
          if current_retry < max_retries
            current_retry += 1
            sleep(calculate_backoff(current_retry))
            retry
          else
            raise e # Continue to Scalable Retry (Topic-based)
          end
        end
      end
    end
  end
end