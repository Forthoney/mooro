# Mooro

A truly parallel, loggable, minimal TCP Server in CRuby.
Mooro's vanilla server is a super compact (< 150 LOC with comments) TCP Server.
Features such as HTTP support or interruptable workers are available through the `Mooro::Impl` module.
The simple architecture means it's easy for you to extend it yourself to fit your needs!

Loosely based on the [GServer](https://github.com/ruby/gserver) specification.

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

    $ bundle add UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

## Usage

If you want to create a basic server that outputs the time,
```ruby
class TimeServer < Mooro::Server
  class << self
    def serve(io)
      io.puts(Time.now.to_i)
    end
  end
end

server = TimeServer.new(max_connections = 4)
server.start
```

You can also build HTTP Servers using the `Mooro::Impl::Http` module.
A healthcheck server like the one [here](https://www.mikeperham.com/2023/09/11/ruby-http-server-from-scratch/) can be built with
```ruby
Http = Mooro::Impl::Http

class HealthCheck < Http::Server
  class << self
    def request_handler(req)
      req.path == "/" ? Http::Response[200] : Http::Response[404]
    end
  end
end
```

Mooro, for the most part, follows GServer's interface. Read more about the differences [here](docs/gserver_differences.md).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Mooro is in desperate need of Tests (both Unit and Integration) and Benchmarks.
I unfortunately lack the expertise needed for either of these, so any contribution in these areas are greatly appreciated.
Contributions outside these areas are, of course, also welcome.

Bug reports and pull requests are welcome on GitHub at https://github.com/Forthoney/mooro. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/Forthoney/mooro/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Mooro project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/Forthoney/mooro/blob/main/CODE_OF_CONDUCT.md).
