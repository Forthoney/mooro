# frozen_string_literal: true

require "async"
require "ractor/tvar"

require_relative "message"
require_relative "ractor_util"

module Mooro
  class Worker
    using RactorUtil

    attr_reader :ractor

    def initialize(logger, app, name:)
      @completed = Ractor::TVar.new(0)
      @prev_completed = 0
      @ractor = Ractor.new(Ractor.current, logger, app, @completed, name:) do |supervisor, logger, app, completed|
        logger.send(Message::Log["Worker #{Ractor.current.name} started".freeze], move: true)

        answer_loop(supervisor) do |env|
          status, fields, body = app.call(env)

          raise ArgumentError, "Status must be an integer!" unless status.is_a?(Integer)
          raise ArgumentError, "Headers must not be nil!" unless fields

          res = generate_response(env, status, fields, body)
          Ractor.atomically { completed.value += 1 }
          res
        end
      end
    end

    # Ask this Worker a question and receive a response
    # Asynchronously yields while the response is not ready
    # @see #question_loop
    # @param question [Object]
    # @param logger [Ractor]
    # @param task [Async::Task]
    # @return [Object]
    def ask(question, logger, task: Async::Task.current)
      @ractor.send(Message::Question[question])

      # wait until result produced
      task.yield while @prev_completed == @completed.value

      # update prev_completed
      @prev_completed += 1
      @ractor.take
    end

    def join
      @ractor.send(Message::Terminate[])
      @ractor.take
    end
  end
end
