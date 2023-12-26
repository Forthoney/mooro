# frozen_string_literal: true
# shareable_constant_value: literal

require "protocol/http1"
require "protocol/rack"
require "async/http"

require "mooro"

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

      Ractor.make_shareable(Protocol::HTTP::Headers::POLICY)

      CRLF = "\r\n"
      SERVER_NAME = "Mooro HttpServer (Ruby #{RUBY_VERSION})"

      protected

      def handle_request(env)
        [200, {}, ["Hello, World!"]]
      end

      def serve(socket, logger)
        conn = Async::HTTP::Protocol::HTTP1::Connection.new(socket, VERSION)

        adapt_app = Protocol::Rack::Adapter.new(->(_env) { [200, {}, ["Hello, World!"]] }, Console.new(logger))

        while (request = next_request(conn))
          response = adapt_app.call(request)
          body = response.body

          return if conn.stream.nil? && body.nil? # Full hijack

          begin
            trailer = response.headers.trailer!
            conn.write_response(VERSION, response.status, response.headers)

            if body && (protocol = response.protocol)
              stream = conn.write_upgrade_body(protocol)
              request = response = nil
              body.call(stream)
            elsif request.connect? && response.success?
              stream = write_tunnel_body(request.version)
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
            request&.each {}
          rescue => error
            raise
          ensure
            body&.close(error)
          end
        end
      end

      def next_request(conn)
        return false unless conn.persistent
        return false unless (request = Async::HTTP::Protocol::HTTP1::Request.read(conn))

        unless conn.persistent?(request.version, request.method, request.headers)
          conn.persistent = false
        end

        request
      end

      Response = Data.define(:status_code, :status_message, :header, :body) do
        def initialize(status_code:, status_message: CODE_MSG[status_code], header: {}, body: "") = super

        def to_s
          header_text = header.map { |k, v| "#{k}: #{v}" + CRLF }.join
          "#{VERSION} #{status_code} #{status_message}#{CRLF}#{header_text}#{body}"
        end

        CODE_MSG = {
          200 => "OK",
          400 => "Bad Request",
          403 => "Forbidden",
          405 => "Method Not Allowed",
          411 => "Length Required",
          500 => "Internal Server Error",
        }
      end
    end
  end
end
