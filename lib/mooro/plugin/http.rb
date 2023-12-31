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
        # parse first line
        socket.gets&.scan(/^(\S+)\s+(\S+)\s+(\S+)/) do |method, path, version|
          header = parse_header(socket)
          return socket << Response[400] if header.nil?

          socket.binmode
          request = Request[socket, header, method, path, version]
          response = handle_request(request)
          return socket << response
        end

        socket << Response[400]
      end

      private

      def parse_header(socket)
        # parse HTTP headers
        header = Header.new { |h, k| h[k] = [] }
        field = nil
        while /^(\n|\r)/.match?(line = socket.gets)
          # Use WEBrick parsing
          case line
          when /^([A-Za-z0-9!\#$%&'*+\-.^_`|~]+):(.*?)\z/om
            field = Regexp.last_match(1).downcase
            header[field] << Regexp.last_match(2).strip
          when /^\s+(.*?)/om && field
            header[field][-1] << " " << line.strip
          else
            return
          end
        end
        header
      end

      class Header < Hash
        def to_s
          export.map { |k, v| "#{k}: #{v.join(", ")}" + CRLF }.join
        end

        private

        def export
          new_header = Header.new { |h, k| h[k] = [] }
          new_header.update(self)
          new_header["server"] << SERVER_NAME
          new_header["connection"] << "close"
          new_header["date"] << http_time(Time.now)
          new_header
        end

        def http_time(time)
          time.gmtime.strftime("%a, %d %b %Y %H:%M:%S GMT")
        end
      end

      Request = Data.define(:data, :header, :method, :path, :proto)

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
