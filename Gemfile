# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in mooro.gemspec
gemspec

gem "rake", "~> 13.0"

group :development do
  gem "rubocop-shopify", "~> 2.14", require: false
  gem "rubocop-rspec", require: false
  gem "steep", require: false
end

group :test do
  gem "rspec", "~> 3.0"
end

# Only need these gems when intending to use the full HTTP capabilities
group :full_http, optional: true do
  gem "protocol-http", "~> 0.25.0"
  gem "protocol-http1", "~> 0.16.0"
  gem "protocol-rack", "~> 0.4.1"
end
