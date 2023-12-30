# frozen_string_literal: true
# shareable_constant_value: literal

require "protocol/rack"

require "mooro"
require_relative "connection"
require_relative "console"

module Mooro
  module Plugin
    module HTTP
      CRLF = "\r\n"
      SERVER_NAME = "Mooro HttpServer (Ruby #{RUBY_VERSION})"

      protected

      def handle_request(env)
        [200, {}, ["Hello, World!"]]
      end

      def serve(socket, logger)
        conn = Connection.new(socket)

        app = Protocol::Rack::Adapter.new(->(_env) { [200, {}, ["Hello, World!"]] }, Console.new(logger))
        conn.serve_app(app)
      end
    end
  end
end
