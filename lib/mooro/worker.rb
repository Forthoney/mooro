# frozen_string_literal: true

require "benchmark"

require "async"
require "ractor/tvar"

require_relative "util/message"
require_relative "util/ractor_helper"
require_relative "util/logger_rpc"

module Mooro
  class Worker
    include Util::Message

    using Util::RactorHelper
    using Util::LoggerRPC

    attr_reader :ractor
    attr_reader :name

    def initialize(logger, app, name:)
      @name = name
      @completed = Ractor::TVar.new(0)
      @prev_completed = 0
      @ractor = Ractor.new(Ractor.current, logger, app, @completed, name:) do |supervisor, logger, app, completed|
        logger.send(Info["Worker #{Ractor.current.name} initialized".freeze], move: true)
        Ractor.current[:logger] = logger

        answer_loop(supervisor) do |env|
          logger.send(Info["Worker #{Ractor.current.name} starting req at #{Process.clock_gettime(Process::CLOCK_MONOTONIC)}".freeze], move: true)
          status, fields, body = app.call(env)

          raise ArgumentError, "Status must be an integer!" unless status.is_a?(Integer)
          raise ArgumentError, "Headers must not be nil!" unless fields

          res = generate_response(env, status, fields, body)
          logger.send(Info["Worker #{Ractor.current.name} completed req at #{Process.clock_gettime(Process::CLOCK_MONOTONIC)}".freeze], move: true)
          Ractor.atomically { completed.value += 1 }
          res
        end
      end
    end

    # Ask this Worker a question and receive a response
    # Asynchronously yields while the response is not ready
    # @see #question_loop
    # @param question [Object]
    # @param task [Async::Task]
    # @return [Object]
    def ask(question)
      @ractor.send(Question[question])
      Async::Task.current.yield until @completed.value > @prev_completed
      @prev_completed += 1
      @ractor.take
    end

    def join
      @ractor.send(Terminate[])
      @ractor.take
    end
  end
end
