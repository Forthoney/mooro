# frozen_string_literal: true

require "socket"

module Chungmuro
  class Server
    def initialize(host = "127.0.0.1", 
                   port = 10001, 
                   max_connections = 4, 
                   stdlog = $stderr)
      @host = host
      @port = port
      @max_connections = max_connections  
      @stdlog = stdlog
      @shutdown = true
    end

    def start(max_connections = nil)
      raise "server is already running" unless @shutdown

      @shutdown = false

      @logger = make_logger
      @listener = make_listener(@logger)
      @workers = (max_connections || @max_connections).times.map do |i|
        make_worker(@listener, @logger, ractor_name: "worker-#{i}") 
      end
    end

    def stop
      @listener.close_outgoing
      Ractor.select(@listener, *@workers)
      @shutdown = true
    end

    protected

    def make_logger(ractor_name: "logger")
      Ractor.new(@stdlog, name: ractor_name) do |out_stream|
        loop do
          msg = Ractor.receive
          out_stream.puts("[#{Time.new.ctime}] #{msg}")
          out_stream.flush
        end
      end
    end

    def make_worker(listener, logger, ractor_name: "worker")
      Ractor.new(listener, logger, name: ractor_name) do |listener, logger|
        client = nil
        loop do
          client = listener.take
          serve(client)
        rescue Ractor::ClosedError
          logger.send("#{name} stop")
          break
        rescue => err
          logger.send(err.to_s)
          retry
        ensure
          client&.close
        end
      end
    end

    def make_listener(logger, ractor_name: "listener")
      Ractor.new(logger, @host, @port, name: ractor_name) do |logger, host, port|
        socket = TCPServer.new(host, port)
        logger.send("#{name} #{host}:#{port} start")

        loop { Ractor.yield(socket.accept, move: true) }
      end
    end
  end
end
