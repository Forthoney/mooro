# frozen_string_literal: true

require "protocol/rack"

module Mooro
  class Adapter < Protocol::Rack::Adapter::Rack3
    def initialize; end
  end
end
