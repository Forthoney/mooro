# frozen_string_literal: true
# shareable_constant_value: literal

require "protocol/rack"

require_relative "connection"
require_relative "console"

module Mooro
  module Impl
    module HTTP
      CRLF = "\r\n"
      SERVER_NAME = "Mooro HTTP::Server (Ruby #{RUBY_VERSION})"

      Ractor.make_shareable(Protocol::HTTP::Headers::POLICY)
      Ractor.make_shareable(Protocol::Rack::Response::HOP_HEADERS)

      class Server < Mooro::Server
        protected

        def handle_request(env)
          [200, {}, ["Hello, World!"]]
        end

        def serve(socket, logger, resources)
          conn = Connection.new(socket)
          app = Protocol::Rack::Adapter.new(resources[:app], Console.new(logger))
          conn.serve_app(app)
        end

        def worker_resources
          { app: Ractor.make_shareable(method(:handle_request).to_proc) }
        end
      end
    end
  end
end
