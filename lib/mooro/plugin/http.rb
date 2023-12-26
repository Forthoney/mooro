# frozen_string_literal: true
# shareable_constant_value: literal

require "protocol/http1"
require "protocol/rack"

require "mooro"

module Mooro
  module Plugin
    module HTTP
      class Server < Protocol::HTTP1::Connection
        def fail_request(status)
          @persistent = false
          write_response(@version, status, {}, nil)
          write_body(@version, nil)
        rescue Erro::ECONNRESET, Errno::EPIPE
        end

        def next_request
          return unless @persistent

          result = read_request
          return if result.nil?

          request = Protocol::HTTP::Request.new("http", *result)

          unless persistent?(request.version, request.method, request.headers)
            @persistent = false
          end

          request
        rescue
          fail_request(400)
          raise
        end
      end

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

      Ractor.make_shareable(Protocol::HTTP::Headers::POLICY)
      Ractor.make_shareable(Protocol::Rack::Response::HOP_HEADERS)

      CRLF = "\r\n"
      SERVER_NAME = "Mooro HttpServer (Ruby #{RUBY_VERSION})"

      protected

      def handle_request(env)
        [200, {}, ["Hello, World!"]]
      end

      def serve(socket, logger)
        conn = Server.new(socket, VERSION)

        adapt_app = Protocol::Rack::Adapter.new(->(_env) { [200, {}, ["Hello, World!"]] }, Console.new(logger))

        while request = conn.next_request
          response = adapt_app.call(request)
          puts response
          body = response.body

          return if conn.stream.nil? && body.nil? # Full hijack

          begin
            if response
              trailer = response.headers.trailer!
              conn.write_response(VERSION, response.status, response.headers)

              if body && (protocol = response.protocol)
                stream = conn.write_upgrade_body(protocol)
                request = response = nil
                body.call(stream)
              elsif request.connect? && response.success?
                stream = conn.write_tunnel_body(request.version)
                request = response = nil
                body.call(stream)
              else
                head = request.head?
                version = request.version
                request = nil unless request.body
                response = nil

                conn.write_body(version, body, head, trailer)
              end
              body = nil
            else
              conn.write_response(VERSION, 500, {})
              conn.write_body(request.version, nil)
            end

            request&.each {}
          rescue => error
            raise
          ensure
            puts body.nil?
            body&.close(error)
          end
        end
      end
    end
  end
end
