# frozen_string_literal: true

require "async"
require "ractor/tvar"

require_relative "message"

module Mooro
  # Utilities for use in Worker
  module WorkerUtil
    # Due to Ractor sharing constraints, if there is a function you know
    # ahead of time that you know you'll want to use inside the Ractor,
    # it's best to add it as a refinement rather than passing it in the Ractor
    # as a proc
    refine Ractor do
      private

      # Runs an event-loop where the current Ractor repeatedly receives
      # "questions" from the questioner, and yields a response.
      # It also informs the questioner when the Ractor is ready for a new response
      # @param questioner [Ractor] The Ractor sending questions to current Ractor
      # @param notify [Boolean] Whether to notify the questioner when done
      # @return [Void]
      def answer_loop(questioner, notify: true, &block)
        loop do
          questioner.send(Ractor.current) if notify # ME! I'm ready for a new question!
          case Ractor.receive
          in Message::Terminate
            break
          in Message::Question(content)
            Ractor.yield(Message::Answer[yield(content)])
          end
        end
      end

      def generate_response(env, status, fields, body)
        headers = Protocol::HTTP::Headers.new
        meta = {}
        fields.each do |key, value|
          key = key.downcase
          if key.start_with?("rack.")
            meta[key] = value
          elsif value.is_a?(Array)
            value.each { |_v| headers[key] = value }
          else
            headers[key] = value
          end
        end
        Protocol::Rack::Response.wrap(env, status, headers, meta, body, nil)
      end
    end
  end

  class Worker
    using RactorUtil

    attr_reader :ractor

    def initialize(logger, app, name:)
      @completed = Ractor::TVar.new(0)
      @prev_completed = 0
      @ractor = Ractor.new(Ractor.current, logger, app, @completed, name:) do |supervisor, logger, app, completed|
        logger.send("Worker #{Ractor.current.name} started")
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
      logger.send("completed #{@prev_completed} reqs") if @prev_completed % 1000 == 0
      @ractor.take
    end
  end
end
