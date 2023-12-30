# frozen_string_literal: true
# shareable_constant_value: literal

require "protocol/http1"
require "protocol/rack"

require "mooro"

module Mooro
  module Plugin
    module HTTP
      class Connection < Protocol::HTTP1::Connection
        attr_reader :version
        attr_reader :count

        def initialize(stream, version = VERSION)
          super(stream)
          @ready = true
          @version = version
        end

        def http1? = true
        def http2? = false

        def peer
          @stream.io
        end

        def concurrency = 1

        def viable?
          @ready && @stream&.connected?
        end

        def reusable?
          @ready && @persistent && @stream && !@stream.closed?
        end

        def serve_app(app)
          while (request = next_request)
            serve_request(app, request)
          end
        end

        private

        def fail_request(status)
          @persistent = false
          write_response(@version, status, {}, nil)
          write_body(@version, nil)
        rescue Erro::ECONNRESET, Errno::EPIPE
        end

        def next_request
          return unless @persistent

          request_data = read_request
          return if result.nil?

          request = Protocol::HTTP::Request.new("http", *request_data)

          unless persistent?(request.version, request.method, request.headers)
            @persistent = false
          end

          request
        rescue
          fail_request(400)
          raise
        end

        def serve_request(app, request)
          response = app.call(request)
          body = response.body

          return if @stream.nil? && body.nil? # Full hijack

          begin
            if response
              trailer = response.headers.trailer!
              write_response(VERSION, response.status, response.headers)

              if body && (protocol = response.protocol)
                stream = write_upgrade_body(protocol)
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

                write_body(version, body, head, trailer)
              end
              body = nil
            else
              write_response(VERSION, 500, {})
              write_body(request.version, nil)
            end

            request&.each {}
          rescue => error
            raise
          ensure
            puts body.nil?
            body&.close(error)
          end
        end

        def read_line?
          @stream.read_until(CRLF)
        end

        def read_line
          @stream.read_line(CRFL) or raise EOFError, "Could not read line!"
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
        conn = Connection.new(socket, VERSION)

        adapt_app = Protocol::Rack::Adapter.new(->(_env) { [200, {}, ["Hello, World!"]] }, Console.new(logger))
        conn.serve_app(adapt_app)
      end
    end
  end
end
