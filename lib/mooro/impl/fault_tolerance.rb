# frozen_string_literal: true

require "mooro"
require "mooro/server"

module Mooro
  module Impl
    module FaultTolerance
      class InterruptableServer < Server
        protected

        def make_worker(supervisor, logger, ractor_name: "interruptable_worker")
          Ractor.new(
            self.class,
            supervisor,
            logger,
            name: ractor_name,
          ) do |server, supervisor, logger|
            clients = Thread::Queue.new
            runner = Thread.new do
              while (current_client = clients.pop)
                begin
                  server.serve(current_client)
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
end
