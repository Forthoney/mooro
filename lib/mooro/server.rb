# frozen_string_literal: true

require "async"
require "async/http/server"
require "async/http/endpoint"
require "ractor/tvar"
require "logger"
require_relative "adapter"
require_relative "message"
require_relative "worker"
require_relative "ractor_util"

module Mooro
  class TerminateServer < StandardError; end

  class Server
    using RactorUtil

    attr_reader :runnin

    def initialize(
      max_connections,
      endpoint = "http://127.0.0.1:10001",
      stdlog = $stderr
    )

      @endpoint = Async::HTTP::Endpoint.parse(endpoint)
      @max_connections = max_connections
      @stdlog = stdlog
      @running = false
    end

    def start
      raise "server is already running" if @running

      @logger = make_logger
      @workers = make_worker_pool
      @supervisor = make_supervisor
      @running = true
    end

    protected

    # Create a logger Ractor which receives messages from supervisor and workers
    #
    # The logger logs messages to @stdlog with the timestamp of when the
    # message was processed by the logger
    #
    # @param name [String] name the ractor
    # @return [Ractor] the logger Ractor
    def make_logger(name: "logger")
      Ractor.new(@stdlog, name:) do |out_stream|
        logger = Logger.new(out_stream)
        logging_loop do |msg|
          logger.info(msg)
        end
      end
    end

    # Create worker pool
    # @return [Hash<Ractor, Mooro::Worker>] Mapping between Ractor id and worker
    def make_worker_pool
      app = Ractor.make_shareable(method(:app).to_proc)

      @max_connections.times.map do |i|
        worker = Worker.new(@logger, app, name: "worker-#{i}")
        [worker.ractor, worker]
      end.to_h
    end

    def app(env)
      [200, {}, ["Hello, World!"]]
    end

    # Create a supervisor Ractor
    #
    # The supervisor dispatches requests for the workers to take on.
    # Supervisor safely terminates on receiving SIGINT.
    # Graceful termination will safely join with workers and logger.
    # Assuming no workers or the logger is blocking, graceful termination guarantees
    # joining with all child ractors. This is becausee workers are guaranteed to
    # survive as long as the supervisor too is alive and well.
    #
    # @return [Void]
    def make_supervisor
      server = Async::HTTP::Server.new(method(:serve_request), @endpoint)
      Async do |task|
        @logger.send(Message::Log["Listening on #{@endpoint}"])
        server_task = task.async do
          server.run
        end
        Signal.trap("TERM") { server_task.stop }
      end
    end

    # Transform Async::HTTP::Request object into Rack env
    # @param request [Async::HTTP::Request] the reqeust from a client
    # @return [Object] the response
    def serve_request(request)
      env = Adapter.new.make_environment(request)
      env = env.slice(*env.keys - ["protocol.http.request", "rack.hijack"])
        .transform_values(&Ractor.method(:make_shareable))

      worker_ractor = Ractor.receive_if { |msg| msg.is_a?(Ractor) }

      case @workers[worker_ractor].ask(env, @logger)
      in Message::Answer(response)
        response
      else
        raise "Response failed"
      end
    end
  end
end
