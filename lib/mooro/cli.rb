# frozen_string_literal: true

require "optparse"

require_relative "server"

module Mooro 
  class CLI
    def initialize(argv)
      options = parse_options(argv.dup)
      s = Server.new(options[:n_workers])
      s.start
    end

    def parse_options(argv)
      options = {}
      OptionParser.new do |parser|
        parser.on("-n", "--n_workers NUM", Integer, "Set number of worker ractors") do |v|
          puts v
          options[:n_workers] = v
        end
      end.parse!(argv)
      options
    end
  end
end
