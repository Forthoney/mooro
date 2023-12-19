# frozen_string_literal: true

# shareable_constant_value: literal

require "mooro"
require "mooro/server"

module Mooro
  module Plugin 
    module Http
      CRLF = "\r\n"
      HTTP_PROTO = "HTTP/1.0"
      SERVER_NAME = "HttpServer (Ruby #{RUBY_VERSION})"
      DEFAULT_HEADER = {
        "Server" => SERVER_NAME,
      }

      STATUS_CODE_MAPPING = {
        200 => "OK",
        400 => "Bad Request",
        403 => "Forbidden",
        405 => "Method Not Allowed",
        411 => "Length Required",
        500 => "Internal Server Error",
      }

      class << self
        protected

        def serve(io)
          # parse first line
          io.gets&.scan(/^(\S+)\s+(\S+)\s+(\S+)/) do |method, path, proto|
            # parse HTTP headers
            header = Header.new
            while /^(\n|\r)/.match?(line = io.gets)
              line&.scan(/^([\w-]+):\s*(.*)$/) do |k, v|
                header[k] = v.strip
              end
            end
            io.binmode
            request = Request.new(io, header, method, path, proto)
            response = request_handler(request)
            return io << response.to_s
          end
          io << Response[400, "Bad Request"].to_s
        end

        def request_handler(request)
          Response[200]
        end
      end
    end

    # A case-insensitive Hash class for HTTP header
    class Header
      include Enumerable

      def initialize(hash = {})
        @hash = hash
        update(hash)
      end

      def [](key)
        @hash[key.to_s.capitalize]
      end

      def []=(key, value)
        @hash[key.to_s.capitalize] = value
      end

      def update(hash)
        hash.each { |k, v| self[k] = v }
        self
      end

      def each
        @hash.each { |k, v| yield k.capitalize, v }
      end

      def map
        @hash.map { |k, v| yield k.capitalize, v }
      end

      def to_s
        export.map do |k, v|
          "#{k}: #{v}" + CRLF
        end.join
      end

      private

      def export
        new_header = Header.new(DEFAULT_HEADER.dup)
        new_header.update(self)
        new_header["connection"] = "close"
        new_header["date"] = http_time(Time.now)
        new_header
      end

      def http_time(time)
        time.gmtime.strftime("%a, %d %b %Y %H:%M:%S GMT")
      end
    end

    Request = Data.define(:data, :header, :method, :path, :proto) do
      def content_length
        header.dig("Content-Length")&.to_i
      end
    end

    Response = Data.define(:status_code, :status_message, :header, :body) do
      def initialize(
        status_code:,
        status_message: STATUS_CODE_MAPPING[status_code],
        header: Header.new,
        body: nil
      ) = super

      def to_s
        "#{HTTP_PROTO} #{status_code} #{status_message}#{CRLF}#{header}#{body unless body.nil}"
      end
    end
  end
end
