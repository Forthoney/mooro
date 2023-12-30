# frozen_string_literal: true

require "protocol/http1"

module Mooro
  module Plugin
    module HTTP
      Ractor.make_shareable(Protocol::HTTP::Headers::POLICY)
      Ractor.make_shareable(Protocol::Rack::Response::HOP_HEADERS)

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
        rescue Errno::ECONNRESET, Errno::EPIPE
        end

        def next_request
          return unless @persistent

          request_data = read_request
          return if result.nil?

          request = Protocol::HTTP::Request.new(self, *request_data)

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
          @stream.gets(CRLF)
        end

        def read_line
          @stream.gets(CRLF) or raise EOFError, "Could not read line!"
        end
      end
    end
  end
end
