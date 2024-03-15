# frozen_string_literal: true

require "async"
require "async/http/server"
require "async/http/endpoint"
require "protocol/rack"
require "ractor/tvar"
require "console"

require_relative "worker"
require_relative "util/message"
require_relative "util/ractor_helper"

module Mooro
  class Server
    include Util::Message
    using Util::RactorHelper

    attr_reader :running

    def initialize(
      n_workers,
      endpoint = "http://127.0.0.1:10001",
      stdlog = $stderr
    )

      @endpoint = Async::HTTP::Endpoint.parse(endpoint)
      @n_workers = n_workers
      @stdlog = stdlog
      @running = false
    end

    def start
      raise "server is already running" if @running

      @logger = make_logger
      @workers = make_worker_pool
      @available_workers = Async::Queue.new

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
      Ractor.new(@stdlog, name:) do |_out_stream|
        logging_loop do |msg|
          Console.info(msg)
        end
      end
    end

    # Create worker pool
    # @return [Hash<Ractor, Mooro::Worker>] Mapping between Ractor id and worker
    def make_worker_pool
      app = Ractor.make_shareable(method(:app).to_proc)

      @n_workers.times.map do |i|
        Worker.new(@logger, app, name: i.to_s)
      end
    end

    def app(env)
      fib = ->(x) { x < 2 ? 1 : fib.call(x - 2) + fib.call(x - 1) }
      fib.call(30)
      [200, {}, ["Hello, World!"]]
    end

    # Create a supervisor Ractor
    #
    # The supervisor dispatches requests for the workers to take on.
    # Supervisor safely terminates on receiving SIGTERM.
    # Graceful termination will safely join with workers and logger.
    # Assuming no workers or the logger is blocking, graceful termination guarantees
    # joining with all child ractors. This is becausee workers are guaranteed to
    # survive as long as the supervisor too is alive and well.
    #
    # @return [Void]
    def make_supervisor
      adapter = Protocol::Rack::Adapter.new(method(:pass_to_worker))
      server = Async::HTTP::Server.new(adapter, @endpoint)
      Async do |task|
        @available_workers.enqueue(*@workers)

        @logger.send(Log["Listening on #{@endpoint}".freeze], move: true)

        server_task = task.async do
          server.run
        end
      end
    end

    # Transform Async::HTTP::Request object into Rack env
    # @param request [Async::HTTP::Request] the reqeust from a client
    # @return [Object] the response
    def pass_to_worker(env)
      env = env.slice(*env.keys - ["protocol.http.request", "rack.hijack"])
        .transform_values(&Ractor.method(:make_shareable))

      selected_worker = @available_workers.dequeue
      @logger.send(Info["Worker #{selected_worker.name} ask: #{Process.clock_gettime(Process::CLOCK_MONOTONIC)}"])

      response = selected_worker.ask(env)

      @logger.send(Info["Worker #{selected_worker.name} answer: #{Process.clock_gettime(Process::CLOCK_MONOTONIC)}"])
      @available_workers << selected_worker
      response
    end
  end
end
