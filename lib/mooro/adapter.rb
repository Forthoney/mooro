# frozen_string_literal: true

require "protocol/rack"

module Mooro
  class Adapter < Protocol::Rack::Adapter::Rack3
    # don't init super since we just need to use a stateless method
    def initialize; end 
  end
end
