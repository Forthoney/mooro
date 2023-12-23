# frozen_string_literal: true
# shareable_constant_value: literal

require "uri"

require "mooro"

module Mooro
  module Plugin
    module HTTP
      CRLF = "\r\n"
      VERSION = "HTTP/1.1"
      SERVER_NAME = "Mooro HttpServer (Ruby #{RUBY_VERSION})"

      protected

      def handle_request(request)
        Response[200]
      end

      def serve(socket)
        case Request.build(socket)
        in Err
          return socket << Response[400]
        in Ok(request)
          return socket << handle_request(request)
        end
      end

      Response = Data.define(:status_code, :status_message, :header, :body) do
        def initialize(status_code:, status_message: CODE_MSG[status_code], header: Header.new, body: "") = super

        def to_s
          "#{VERSION} #{status_code} #{status_message}#{CRLF}#{header}#{body}"
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
