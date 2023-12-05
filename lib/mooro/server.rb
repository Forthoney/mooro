# frozen_string_literal: true

require "socket"

module Mooro
  class Server
    class << self
      # Logic on how to serve each client
      # Server.serve must be a pure function, and any variables must be passed explicitly
      # The only means of passing a Method or Proc as a nested proc are currently hacky
      # Mooro's workaround is to define a class method, which is able to be called
      # This comes with the caveat that no shared object can live in the function body
      def serve(io)
        io.puts("hello world")
      end
    end

    def initialize(max_connections,
      host = "127.0.0.1",
      port = 10001,
      stdlog = $stderr)

      @host = host
      @port = port
      @max_connections = max_connections
      @stdlog = stdlog
      @shutdown = true
    end

    def start(max_connections = nil)
      raise "server is already running" unless @shutdown

      max_connections ||= @max_connections
      @shutdown = false

      @logger = make_logger
      @listener = make_listener(@logger)
      @workers = max_connections.times.map do |i|
        make_worker(@listener, @logger, ractor_name: "worker-#{i}")
      end
    end

    def stop
      raise "server is not yet running" if @shutdown

      @listener.send(:terminate)

      @workers.each(&:take)

      @logger.send(:terminate)
      @logger.take

      raise "orphaned ractor" unless Ractor.count == 1

      @shutdown = true
    end

    protected

    # Create a logger Ractor
    # The logger logs messages to @stdlog with the timestamp of when the
    # message was processed
    # workers & listener ----> logger
    # Workers and the listener will send messages to logger (push based)
    # Logger only yields one value
    # Logger terminates on receiving :terminate
    def make_logger(ractor_name: "logger")
      Ractor.new(@stdlog, name: ractor_name) do |out_stream|
        until (msg = Ractor.receive) == :terminate
          out_stream.puts("[#{Time.new.ctime}] #{msg}")
          out_stream.flush
        end
      end
    end

    # Create a worker Ractor
    # The worker actually serves the client
    # listener --->> worker ----> logger
    # Workers take a client from the listener (pull based)
    # and send messages to logger when non-standard behavior occurs (push based)
    # Worker terminates when the listener closes its outgoing port
    def make_worker(listener, logger, ractor_name: "worker")
      Ractor.new(self.class, listener, logger, name: ractor_name) do |server, listener, logger|
        loop do
          client = listener.take
          server.serve(client)
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

    # Create a listener Ractor
    # The listener dispatches clients for the workers to take on
    # listener --->> worker
    # listener ----> logger
    # Listener terminates on receiving :terminate
    def make_listener(logger, ractor_name: "listener")
      Ractor.new(logger, @host, @port, name: ractor_name) do |logger, host, port|
        socket = TCPServer.new(host, port)
        logger.send("#{name} #{host}:#{port} start")

        Ractor.current.send(true)
        until Ractor.receive == :terminate
          Ractor.current.send(true) # send itself any message other than :terminate
          Ractor.yield(socket.accept, move: true)
        end

        logger.send("#{name} #{host}:#{port} stop")
        # Need to explicitly close_outgoing to not put anything in the outgoing
        # queue when returning. Otherwise, a worker will take that output
        Ractor.current.close_outgoing
      end
    end
  end
end
