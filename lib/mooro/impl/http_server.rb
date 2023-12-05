# frozen_string_literal: true

# sharable_constant_value: literal

require "mooro"
require "mooro/server"

module Mooro
  module Impl
    class HttpServer < Server
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

      # A case-insensitive Hash class for HTTP header
      class Table
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

        def map
          @hash.map { |k, v| yield k.capitalize, v }
        end
      end

      class Request
        attr_reader :data, :header, :method, :path, :proto

        def initialize(data, method = nil, path = nil, proto = nil)
          @header = Table.new
          @data = data
          @method = method
          @path = path
          @proto = proto
        end

        def content_length
          len = @header["Content-Length"]
          return if len.nil?

          len.to_i
        end
      end

      # Request = Data.define(:data, :method, :path, :proto) do
      #   def initialize(data, method=nil)
      # end
      # Response = Data.define(:status, :status_message, :header, :body)

      class Response
        attr_reader   :header
        attr_accessor :body, :status, :status_message

        def initialize(status = 200)
          @status = status
          @status_message = nil
          @header = Table.new
        end
      end

      class << self
        def http_header(header = nil)
          new_header = Table.new(DEFAULT_HEADER)
          new_header.update(header) unless header.nil?

          new_header["connection"] = "close"
          new_header["date"] = http_date(Time.now)
          new_header
        end

        def http_date(time)
          time.gmtime.strftime("%a, %d %b %Y %H:%M:%S GMT")
        end

        def http_resp(status_code, status_message = nil, header = nil, body = nil)
          status_message ||= STATUS_CODE_MAPPING[status_code]

          str = "#{HTTP_PROTO} #{status_code} #{status_message}" + CRLF
          str += http_header(header).map do |k, v|
            "#{k}: #{v}" + CRLF
          end.join
          str += body unless body.nil?
          str
        end

        def serve(io)
          request = nil
          # parse first line
          io.gets.scan(/^(\S+)\s+(\S+)\s+(\S+)/) do |a, b, c|
            request = Request.new(io, a, b, c)
          end
          return io << http_resp(400, "Bad Request") if request.nil?

          # parse HTTP headers
          while /^(\n|\r)/.match?(line = io.gets)
            line.scan(/^([\w-]+):\s*(.*)$/) do |a, b|
              request.header[a] = b.strip
            end
          end

          io.binmode
          response = Response.new
          request_handler(request, response)
          io << http_resp(response.status, response.status_message, response.header, response.body)
        end
      end
    end
  end
end
