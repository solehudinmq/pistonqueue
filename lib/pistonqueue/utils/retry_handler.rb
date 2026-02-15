module Pistonqueue
  module RetryHandler
    def retry_with_exponential_backoff_jitter(max_retries:)
      current_retry = 0
      begin
        yield
      rescue => e
        if current_retry < max_retries
          current_retry += 1

          # exponential backoff: (2^n) + jitter
          calculate_backoff = (2**current_retry) + rand(0.0..1.0)
          sleep(calculate_backoff)
          retry
        else
          raise e # continue to scalable retry (topic-based)
        end
      end
    end
  end
end