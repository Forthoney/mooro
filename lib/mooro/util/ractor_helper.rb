# frozen_string_literal: true

require "async"
require "console"

module Mooro
  module Util
    module RactorHelper
      # Due to Ractor sharing constraints, if there is a function you know
      # ahead of time that you know you'll want to use inside the Ractor,
      # it's best to add it as a refinement rather than passing it in the Ractor
      # as a proc
      refine Ractor do
        private

        # Runs an event-loop where the current Ractor repeatedly receives
        # "questions" from the questioner, and yields a response.
        # It also informs the questioner when the Ractor is ready for a new response
        # @param questioner [Ractor] The Ractor sending questions to current Ractor.
        # @param notify [Boolean] Whether to notify the questioner when done
        # @return [Void]
        def answer_loop(questioner, &block)
          loop do
            questioner.send(Ractor.current) # ME! I'm ready for a new question!
            case Ractor.receive
            in Message::Terminate
              break
            in Message::Question(content)
              Ractor.yield(Message::Answer[yield(content)])
            end
          end
        end

        def logging_loop(&block)
          loop do
            case Ractor.receive
            in Message::Terminate
              break
            in Message::Log(content)
              yield(content)
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
  end
end
