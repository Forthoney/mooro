# frozen_string_literal: true
# shareable_constant_value: literal

require "protocol/rack"

require "mooro"
require_relative "connection"

module Mooro
  module Plugin
    module HTTP
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

      CRLF = "\r\n"
      SERVER_NAME = "Mooro HttpServer (Ruby #{RUBY_VERSION})"

      protected

      def handle_request(env)
        [200, {}, ["Hello, World!"]]
      end

      def serve(socket, logger)
        conn = Connection.new(socket, VERSION)

        adapt_app = Protocol::Rack::Adapter.new(->(_env) { [200, {}, ["Hello, World!"]] }, Console.new(logger))
        conn.serve_app(adapt_app)
      end
    end
  end
end
