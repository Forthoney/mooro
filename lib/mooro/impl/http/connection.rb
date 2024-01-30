# frozen_string_literal: true

require "protocol/http1"

# from https://github.com/socketry/async-http/blob/main/lib/async/http/protocol/http1/server.rb

module Mooro
  module Impl 
    module HTTP
      class Connection < Protocol::HTTP1::Connection
        def initialize(stream, version = "HTTP/1.1")
          super(stream)
          @ready = true
          @version = version
        end

        def serve_app(app)
          while (request = next_request)
            response = app.call(request)
            body = response.body

            return if @stream.nil? && body.nil? # Full hijack

            begin
              if response
                version = request.version
                trailer = response.headers.trailer!
                write_response(version, response.status, response.headers)

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
                  request = nil unless request.body
                  response = nil

                  write_body(version, body, head, trailer)
                end
                body = nil
              else
                write_response(version, 500, {})
                write_body(version, nil)
              end

              request&.each {}
            rescue => error
              raise
            ensure
              body&.close(error)
            end
          end
        end

        private

        def fail_request(status)
          @persistent = false
          write_response(@version, status, {}, nil)
          write_body(@verision, nil)
        rescue Errno::ECONNRESET, Errno::EPIPE
        end

        def next_request
          return false unless @persistent

          request_data = read_request
          return false if request_data.nil?

          request = Protocol::HTTP::Request.new("http", *request_data, nil)

          unless persistent?(request.version, request.method, request.headers)
            @persistent = false
          end

          request
        rescue
          fail_request(400)
          raise
        end
      end
    end
  end
end
