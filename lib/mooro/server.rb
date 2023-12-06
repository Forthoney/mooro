# frozen_string_literal: true

require "socket"

module Mooro
  class StopServer < StandardError; end

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

    def start
      raise "server is already running" unless @shutdown

      @shutdown = false

      @logger = make_logger
      @workers = @max_connections.times.map do |i|
        make_worker(Ractor.current, @logger, ractor_name: "worker-#{i}")
      end
      @supervisor = make_supervisor(@logger, @workers)
      @workers
    end

    def stop
      raise "server is not yet running" if @shutdown

      @supervisor.raise(Mooro::StopServer.new("stop"))
      @supervisor.join
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
        until (client = listener.take) == :terminate
          begin
            server.serve(client)
            client.close
          rescue Ractor::ClosedError => closed_err
            logger.send("#{closed_err}: Listener's outgoing port is closed")
            break
          rescue => err
            logger.send(err.to_s)
            client&.close
          end
        end
      end
    end

    # Create a listener Ractor
    # The listener dispatches clients for the workers to take on
    # listener --->> worker
    # listener ----> logger
    # Listener terminates on receiving an Integer representing the number
    # of workers to send the :terminate message to
    #
    # Listener will send itself true if socket has been accepted in previous iter
    # false if it still needs to wait
    def make_supervisor(logger, workers)
      Thread.new(logger, workers.dup, TCPServer.new(@host, @port)) do |logger, workers, socket|
        logger.send("listener #{@host}:#{@port} start")

        loop do
          client = socket.accept
          Ractor.yield(client, move: true)
        rescue Mooro::StopServer
          logger.send("listener #{@host}:#{@port} stop")
          break
        rescue => err
          logger.send(err.to_s)
          break
        end

        # Termination process
        until workers.empty?
          Ractor.yield(:terminate)
          r, _ = Ractor.select(*workers)
          workers.delete(r)
        end
        logger.send(:terminate)
      end
    end
  end
end
