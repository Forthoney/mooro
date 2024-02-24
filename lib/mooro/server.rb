# frozen_string_literal: true

require "async"
require "async/http/server"
require "async/http/endpoint"
require "ractor/tvar"
require_relative "adapter"
require_relative "message"
require_relative "worker"

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
      app = Ractor.make_shareable(method(:app).to_proc)

      @max_connections.times.map do |i|
        worker = Worker.new(@logger, app, name: "worker-#{i}")
        [worker.ractor, worker]
      end.to_h
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

    def make_supervisor
      server = Async::HTTP::Server.new(method(:serve_request), @endpoint)
      Async do |task|
        task.async do
          server.run
        end
      end
    end

    def serve_request(request)
      env = Adapter.new.make_environment(request)
      shareable_env = env.dup.filter { |_, v| Ractor.shareable?(v) }
      worker_ractor = Ractor.receive_if { |msg| msg.is_a?(Ractor) }

      puts "ask"
      case @workers[worker_ractor].ask(shareable_env)
      in Message::Answer(response)
        puts "answer"
        return response
      else
        raise "Response failed"
      end
    end
  end
end
