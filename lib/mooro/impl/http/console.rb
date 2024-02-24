# frozen_string_literal: true

module Mooro
  module Impl
    module HTTP
      # Console wrapper for the logger ractor
      class Console
        def initialize(logger)
          @logger = logger
        end

        def logger
          self
        end

        def info(message, &block)
          @logger.send("CONSOLE INFO" + message.to_s)
        end

        def debug(message, &block)
          @logger.send("CONSOLE DEBUG" + message.to_s)
        end

        def warn(message, &block)
          @logger.send("CONSOLE WARN" + message.to_s)
        end

        def error(message, &block)
          @logger.send("CONSOLE ERROR" + message.to_s)
        end

        def fatal(message, &block)
          @logger.send("CONSOLE FATAL" + message.to_s)
        end
      end
    end
  end
end
