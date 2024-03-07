# frozen_string_literal: true

require "console"

require_relative "message"

module Mooro
  module Util
    module LoggerStub
      include Message

      refine Console::Logger do
        def info(message)
          Ractor.current[:logger].send(Info[message.to_s.freeze])
        end

        def debug(message)
          Ractor.current[:logger].send(Debug[message.to_s.freeze])
        end

        def warn(message)
          Ractor.current[:logger].send(Warn[message.to_s.freeze])
        end

        def error(message)
          Ractor.current[:logger].send(Error[message.to_s.freeze])
        end

        def fatal(message)
          Ractor.current[:logger].send(Fatal[message.to_s.freeze])
        end
      end
    end
  end
end
