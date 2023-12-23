# frozen_string_literal: true
# shareable_constant_value: literal

require "uri"

module Mooro
  module Plugin
    module HTTP
      class Request
        REQUEST_LINE_REGEX = %r{^(\S+)\s+(\S++)(?:\s+HTTP/(\d+\.\d+))?\r?\n}mo
        MAX_URI_LENGTH = 2083
        MAX_HEADER_LENGTH = 112 * 1024
        ESCAPED = /%([0-9a-fA-F]{2})/

        # Address info
        attr_reader :peeraddr, :addr

        # Request line
        attr_reader :request_time, :request_method, :unparsed_uri, :http_version

        attr_reader :header

        # Accept info
        attr_reader :accept, :accept_charset, :accept_encoding, :accept_langauge

        # Forwarding info
        attr_reader :forwarded_server, :forwarded_proto, :forwarded_host
        attr_reader :forwarded_port, :forwarded_for

        # Uri info
        attr_reader :request_uri, :path, :host, :port

        attr_reader :keep_alive

        attr_accessor :script_name, :path_info, :query_string, :user

        def initialize(
          addr_info:, time:, method:, http_version:, header:, accept_info:,
          forwarded_info: nil, uri_info: nil, keep_alive: false
        )
          @peeraddr, @addr = addr_info
          @request_time = time
          @request_method = method
          @http_version = http_version
          @header = header
          @accept, @accept_charset, @accept_encoding, @accept_language = accept_info
          @forwarded_server, @forwarded_proto,
          @forwarded_host, @forwarded_port, @forwarded_for = forwarded_info
          @request_uri, @path, @host, @port, @query_string = uri_info
          @keep_alive = keep_alive

          @path_info = path.dup
          @user = nil
          @script_name = ""
        end

        def meta_vars
          content_length = header["content-length"]
          content_type = header["content-type"]
          meta = {
            "CONTENT_LENGTH": content_length.to_i > 0 ? cl : nil,
            "CONTENT_TYPE": content_type.dup,
            "GATEWAY_INTERFACE": "CGI/1.1",
            "PATH_INFO": path_info ? path_info.dup : "",
            "QUERY_STRING": query_string ? query_string : "",
            "REMOTE_ADDR": peeraddr[3],
            "REMOTE_HOST": peeraddr[2],
            "REMOTE_USER": user,
            "REQUEST_METHOD": request_method,
            "REQUEST_URI": request_uri,
            "SCRIPT_NAME": script_name,
            "SERVER_NAME": host,
            "SERVER_PORT": port.to_s,
            "SERVER_PROTOCOL": "HTTP/1.1",
            "SERVER_SOFTWARE": "Mooro HTTP",
          }
          meta.each do |key, val|
            next if key.match?(/^content-type$/i) || key.match?(/^content-length$/i)

            name = "HTTP_" + key
            meta[name.gsub(/-/o, "_").upcase] = val
          end
          meta
        end

        class << self
          def build(socket)
            begin
              addr_info = AddrInfo.from_socket(socket)
            rescue Errno::ENOTCONN
              return Err["eof"]
            end

            read_request_line(socket).unwrap do |bytes, time, method, unparsed_uri, http_version|
              read_header(socket, bytes).unwrap do |_bytes, header|
                accept_info = AcceptInfo.from_header(header)

                return Ok if method == "CONNECT" || unparsed_uri == "*"

                forwarded_info = ForwardedInfo.from_header(header)
                begin
                  request_uri = parse_uri(unparsed_uri, forwarded_info, header, addr)
                  uri_info = URIInfo.from_uri(request_uri)
                rescue
                  return Err["bad URI '#{unparsed_uri}'"]
                end

                keep_alive = case header["connection"]
                when /\Aclose\z/io
                  false
                when /\Akeep-alive\z/io
                  true
                else
                  http_version < "1.1"
                end

                Ok[Request.new(
                  time:,
                  method:,
                  http_version:,
                  keep_alive:,
                  header:,
                  accept_info:,
                  addr_info:,
                  uri_info:,
                  forwarded_info:,
                )]
              end
            end
          end

          private

          def read_request_line(socket)
            request_line = socket.gets
            request_line.scan(REQUEST_LINE_REGEX) do |request_method, unparsed_uri, http_version|
              request_bytes = request_line.bytesize
              if (request_bytes >= MAX_URI_LENGTH) && (request_line[-1, 1] != LF)
                return Err["request uri too large"]
              end

              return Ok[[request_bytes, Time.now, request_method, unparsed_uri, http_version]]
            end

            rl = request_line.sub(/\x0d?\x0a\z/o, +"")
            Err["bad Request-Line #{rl}"]
          end

          def read_header(socket, request_bytes)
            until (line = socket.gets).match?(/\A(#{CRLF}|#{LF})\z/om)
              request_bytes += line.bytesize
              return Err["request entity header too large"] if request_bytes > MAX_HEADER_LENGTH

              header = Hash.new { |h, k| h[k] = [] }
              case line
              in /^([A-Za-z0-9!\#$%&'*+\-.^_`|~]+):(.*?)\z/om
                field = Regexp.last_match(1).downcase
                value = Regexp.last_match(2).strip
                header[field] << value
              in /^\s+(.*?)/om unless field.nil?
                header[field][-1] << " " << line.strip
              else
                return Err["bad Request '#{line}'"]
              end
            end

            content_length = header["content-length"]
            if content_length.length > 1
              return Err["badrequest, multiple content-length request headers"]
            elsif content_length == 1 && !content_length[0].match?(/\A\d+\z/)
              return Err["Bad request, invalid content-length request header"]
            end

            Ok[[request_bytes, header]]
          end

          def parse_uri(str, fwd, header, addr)
            uri = URI.parse(str.sub(%r{\A/+}o, "/"))
            return uri if uri.absolute?

            host, port = if fwd.host
              [fwd.host, fwd.port]
            elsif !header["host"].empty?
              header["host"].scan(/\A(#{URI::REGEXP::PATTERN::HOST})(?::(\d+))?\z/no)[0]
            elsif !addr.empty?
              addr[0..2]
            else
              raise "config not implemented"
            end

            uri.scheme = fwd.proto || "http"
            uri.host = host
            uri.port = port&.to_i
            URI.parse(uri.to_s)
          end
        end
      end

      AddrInfo = Data.define(:peeraddr, :addr) do
        class << self
          def from_socket(socket)
            peeraddr = socket.respond_to?(:peeraddr) ? socket.peeraddr : []
            addr = socket.respond_to?(:addr) ? socket.addr : []
            AddrInfo[peeraddr, addr]
          end
        end
      end

      URIInfo = Data.define(:uri, :path, :host, :port, :query_string) do
        class << self
          def from_uri(request_uri)
            path = normalize_path(unescape(request_uri.path))
            host = request_uri.host
            port = request_uri.port
            query_string = request_uri.query
            URIInfo[request_uri, path, host, port, query_string]
          end

          private

          def unescape(str)
            str.b.gsub(ESCAPED) { _1.hex.chr }
          end

          def normalize_path(path)
            raise "abnormal path `#{path}'" unless path[0] == "/"

            ret = path.dup

            ret.gsub!(%r{/+}o, "/")                    # //      => /
            while ret.sub!(%r'/\.(?:/|\Z)', "/"); end  # /.      => /
            while ret.sub!(%r'/(?!\.\./)[^/]+/\.\.(?:/|\Z)', "/"); end # /foo/.. => /foo

            raise "abnormal path `#{path}'" if %r{/\.\.(/|\Z)} =~ ret

            ret
          end
        end
      end

      ForwardedInfo = Data.define(:server, :proto, :host, :port, :for) do
        PRIVATE_NETWORK_REGEXP = %r{
          ^unknown$|
          ^((::ffff:)?127.0.0.1|::1)$|
          ^(::ffff:)?(10|172\.(1[6-9]|2[0-9]|3[01])|192\.168)\.
        }ixo

        class << self
          def from_header(header)
            server = header["x-forwarded-server"].split(",", 2).first
            proto = header["x-forwarded-proto"].split(",", 2).first

            host_port = header["x-forwarded-host"].split(",", 2).first
            host, tmp = if /\A(\[[0-9a-fA-F:]+\])(?::(\d+))?\z/ =~ host_port
              [Regexp.last_match(1), Regexp.last_match(2)]
            else
              host_port.split(":", 2)
            end

            port = tmp&.to_i || (forwarded_proto == "https" && 443 || 80)

            addrs = header["x-forwarded-server"]
            for_ = addrs.split(",")
              .collect(&:strip)
              .reject { |ip| ip.match?(PRIVATE_NETWORK_REGEXP) }
              .first

            ForwardedInfo[server, proto, host, port, for_]
          end
        end
      end

      AcceptInfo = Data.define(:accept, :charset, :encoding, :language) do
        class << self
          def from_header(header)
            accept = parse_qvalues(header["accept"])
            accept_charset = parse_qvalues(header["accept-charset"])
            accept_encoding = parse_qvalues(header["accept-encoding"])
            accept_language = parse_qvalues(header["accept-language"])
            AcceptInfo[accept, accept_charset, accept_encoding, accept_language]
          end

          private

          def parse_qvalues(values)
            values.filter_map do |part|
              if /^([^\s,]+?)(?:;\s*q=(\d+(?:\.\d+)?))?$/ =~ part
                val = Regexp.last_match(1)
                q = Regexp.last_match(2) || 1
                [val, q.to_f]
              end
            end.sort_by { -_2 }.collect { _1 }
          end
        end
      end
    end
  end
end
