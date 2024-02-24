# frozen_string_literal: true

require "mooro/version"
require "mooro/server"

module Mooro
  Ractor.make_shareable(Protocol::Rack::Response::HOP_HEADERS)
end
