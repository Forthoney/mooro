# frozen_string_literal: true

require "mooro"
require "mooro/server"

module Mooro
  module Plugin
    module InterruptableServer
      def make_worker(supervisor, logger, ractor_name: "interruptable_worker")
        block = Ractor.make_shareable(method(:serve).to_proc)
        Ractor.new(supervisor, logger, block, name: ractor_name) do |supervisor, logger, serve|
          clients = Thread::Queue.new
          runner = Thread.new do
            while (current_client = clients.pop)
              begin
                serve.call(current_client)
              rescue TerminateServer
                break
              rescue => err
                logger.send(err.to_s)
              ensure
                current_client&.close
              end
            end
          end
          begin
            until (client = supervisor.take) == :terminate
              clients.push(client)
            end
          rescue Ractor::ClosedError => closed_err
            logger.send("#{closed_err}: Supervisor's outgoing port is closed")
          ensure
            runner.raise(TerminateServer)
            runner.join
          end
        end
      end
    end
  end
end
