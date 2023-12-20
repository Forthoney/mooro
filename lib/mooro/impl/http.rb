# frozen_string_literal: true
# shareable_constant_value: literal

require "mooro"
require "mooro/server"

module Mooro
  module Impl
    # A rudimentary HTTP server based off of gserver/xmlrpc.rb with
    # bits of WEBRICK sprinkled in where xmlrpc is incorrect
    # It serves more of a demonstration purpose although it can suit
    # small internal applications.
    module Http
      CRLF = "\r\n"
      HTTP_PROTO = "HTTP/1.0"
      SERVER_NAME = "Mooro HttpServer (Ruby #{RUBY_VERSION})"

      STATUS_CODE_MAPPING = {
        200 => "OK",
        400 => "Bad Request",
        403 => "Forbidden",
        405 => "Method Not Allowed",
        411 => "Length Required",
        500 => "Internal Server Error",
      }

      class Server < Mooro::Server
        protected

        def handle_request(request)
          Response[200]
        end

        def serve(io)
          # parse first line
          io.gets&.scan(/^(\S+)\s+(\S+)\s+(\S+)/) do |method, path, proto|
            header = parse_header(io)
            return io << Response[400].to_s if header.nil?

            io.binmode
            request = Request[io, header, method, path, proto]
            response = handle_request(request)
            return io << response.to_s
          end

          io << Response[400].to_s
        end

        private

        def parse_header(io)
          # parse HTTP headers
          header = Header.new { |h, k| h[k] = [] }
          field = nil
          while /^(\n|\r)/.match?(line = io.gets)
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
      end

      class Header < Hash
        DEFAULT_HEADER = {
          "server": SERVER_NAME,
        }

        def to_s
          export.map { |k, v| "#{k}: #{v.join(", ")}" + CRLF }.join
        end

        private

        def export
          new_header = Header.new
          new_header.update(DEFAULT_HEADER)
          new_header.update(self)
          new_header["connection"] = "close"
          new_header["date"] = http_time(Time.now)
          new_header
        end

        def http_time(time)
          time.gmtime.strftime("%a, %d %b %Y %H:%M:%S GMT")
        end
      end

      Request = Data.define(:data, :header, :method, :path, :proto)

      Response = Data.define(:status_code, :status_message, :header, :body) do
        def initialize(
          status_code:,
          status_message: STATUS_CODE_MAPPING[status_code],
          header: Header.new,
          body: nil
        ) = super

        def to_s
          "#{HTTP_PROTO} #{status_code} #{status_message}#{CRLF}#{header}#{body unless body.nil?}"
        end
      end
    end
  end
end
