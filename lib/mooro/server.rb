# frozen_string_literal: true

require "socket"
require "async"
require "async/http/server"
require "async/http/endpoint"
require_relative "console"

module Mooro
  class TerminateServer < StandardError; end

  class Server
    def initialize(
      max_connections,
      endpoint = "http://127.0.0.1:10001",
      stdlog = $stderr
    )

      @endpoint = Async::HTTP::Endpoint.parse(endpoint)
      @max_connections = max_connections
      @stdlog = stdlog
      @shutdown = true
    end

    # Start the server. If all goes well, the TCPServer socket is guaranteed
    # to be open when this method returns. If some error occurs, an error will
    # be thrown
    def start
      raise "server is already running" unless @shutdown

      @logger = make_logger
      @workers = make_worker_pool
      @supervisor = make_supervisor
      @shutdown = false
    end

    def stop
      raise "server is not yet running" if @shutdown

      @supervisor.raise(Mooro::TerminateServer.new) if @supervisor.alive?
      @supervisor.join

      raise "orphaned ractor" unless Ractor.count == 1

      @shutdown = true
    end

    def running?
      !@shutdown
    end

    protected

    def serve(socket, logger, resources)
      socket.puts("Hello, World!")
    end

    # Create a logger Ractor
    # workers & supervisor ----> logger
    #
    # The logger logs messages to @stdlog with the timestamp of when the
    # message was processed
    # Workers and the supervisor will send messages to logger (push based)
    #
    # Termination:
    # Logger only yields once when it terminates. Do not take from it unless
    # joining - the taking thread will hang otherwise
    def make_logger(ractor_name: "logger")
      Ractor.new(@stdlog, name: ractor_name) do |out_stream|
        until (msg = Ractor.receive) == :terminate
          out_stream.puts("[#{Time.new.ctime}] #{msg}")
          out_stream.flush
        end
      end
    end

    def make_worker_pool
      serve_proc = Ractor.make_shareable(method(:serve).to_proc)
      resources = Ractor.make_shareable(worker_resources)

      @max_connections.times.map do |i|
        make_worker(serve_proc, resources, name: "worker-#{i}")
      end
    end

    # Create a worker Ractor
    # supervisor >---- worker ----> logger
    #
    # The worker actually serves the client
    # Workers take a client from the supervisor (pull based)
    # and send messages to logger when non-ractor exceptions are raised (push based)
    #
    # Termination:
    # Workers do not stop while the supervisor is alive unless explicitly told to
    def make_worker(serve_proc, worker_resources, name: "worker")
      Ractor.new(
        Ractor.current,
        @logger,
        serve_proc,
        worker_resources,
        name:,
      ) do |supervisor, logger, serve, resources|
        # Failure point 1: supervisor.take
        # - ClosedError: supervisor is already dead
        # - RemoteError: supervisor raised some unhandled error
        # Neither are really recoverable...
        until (client = supervisor.take) == :terminate
          # Failure point 2: server.serve
          # Rescue any error and move on to next client
          begin
            addr = client.peeraddr
            logger.send("client: #{addr[1]} #{addr[2]}<#{addr[3]}> connect")
            serve.call(client, logger, resources)
          rescue => err
            logger.send([err.to_s, err.backtrace])
          ensure
            logger.send("client: #{client.peeraddr[1]} disconnect")
            client&.close
          end
        end
      rescue Ractor::ClosedError => closed_err
        logger.send("#{closed_err}: Supervisor's outgoing port is closed")
      end
    end

    # Create a supervisor Ractor
    #
    # supervisor >---- worker
    #          |-----> logger
    #
    # The supervisor dispatches clients for the workers to take on
    # Supervisor safely terminates on receiving TerminateServer error.
    # This will be triggered remotely by the main thread on the main ractor.
    # Graceful termination will safely join with workers and logger.
    # Assuming no workers or the logger is blocking, graceful termination guarantees
    # joining with all child ractors. This is becausee workers are guaranteed to
    # survive as long as the supervisor too is alive and well.
    #
    # Termination:
    # Any other error will trigger a "non-graceful" termination.
    # We do not know if any child ractors are in a blocking state, so we cannot
    # yield or take from any of them without risk of blocking the supervisor.
    # So, the supervisor does not attempt to join.
    def app(env)
      [200, {}, ["Hello, World!"]]
    end

    def send_to_worker(request)
      adapter =  Protocol::Rack::Adapter.new(Ractor.make_shareable(self.method(:app).to_proc), Impl::HTTP::Console.new(@logger))
      Ractor.yield(adapter)
    end

    def make_supervisor
      server = Async::HTTP::Server.new(self.method(:send_to_worker), @endpoint)
      Async do |task|
        server_task = task.async do 
          server.run
        end
      end
      # Dupe workers array because we mutate it when stopping
      # Thread.new(@logger, @workers.dup, @host, @port) do |logger, workers, host, port|
      #   logger.send("supervisor starting...")
      #
      #   TCPServer.open(host, port) do |socket|
      #     port = socket.addr[1]
      #     logger.send("supervisor successfully started at http://#{host}:#{port}")
      #
      #     loop do
      #       client = socket.accept
      #       Ractor.yield(client, move: true)
      #     rescue TerminateServer
      #       logger.send("supervisor gracefully stopping...")
      #       # Consider changing to push-only once round-robin scheduling is implemented in Ractor.select
      #       until workers.empty?
      #         Ractor.yield(:terminate)
      #         r, _ = Ractor.select(*workers)
      #         workers.delete(r)
      #       end
      #       break
      #     end
      #   rescue => unexpected_err
      #     logger.send("supervisor at crashed with #{unexpected_err}")
      #   end
      #   logger.send(:terminate)
      #   logger.take # join with logger
      # end
    end

    # Resources to be passed to the worker. All values must be shareable or made
    # shareable. The default server doesn't pass anything additional to the worker
    def worker_resources = {}
  end
end
