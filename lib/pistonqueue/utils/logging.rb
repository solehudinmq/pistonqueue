require "logger"

module Pistonqueue
  module Logging
    def self.logger
      @logger ||= begin
        log = ::Logger.new(STDOUT)
        
        log.level = ENV.fetch('LOG_LEVEL', 'INFO').upcase
        
        log.formatter = proc do |severity, datetime, progname, msg|
          log_payload = {
            timestamp: datetime.iso8601,
            level: severity,
            pid: Process.pid,
            thread_id: Thread.current.object_id,
            fiber_id: Fiber.current.object_id,
            context: progname,
            message: msg
          }
          "#{log_payload.to_json}\n"
        end
        
        log
      end
    end

    def logger
      @logger_context ||= self.class.name
      LogProxy.new(::Pistonqueue::Logging.logger, @logger_context)
    end

    class LogProxy
      def initialize(logger, context)
        @logger = logger
        @context = context
      end

      [:debug, :info, :warn, :error, :fatal].each do |level|
        define_method(level) do |msg|
          @logger.send(level, @context) { msg }
        end
      end
    end
  end
end