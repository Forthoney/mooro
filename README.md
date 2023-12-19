# Mooro: A truly parallel, super compact TCP Server in CRuby.

Mooro is a no-dependency, parallel TCP Server with essential features like **logging, worker-pooling, and graceful-stopping**.

## Uncompromising Minimalism
Mooro aims to deliver most if not all essential features expected from a modern Ruby web server such as
* **Parallel**. Mooro utilizes true parallelism with CRuby through `Ractor`s.
* **Loggable**. Supervisor start/stop, worker errors, and other notable events are logged by default, and adding additional logging points is as simple as adding `logger.send("message")`.
* **Stoppable**. Capable of gracefully stopping (or forcefully, if you would prefer that).

At the same time, it abstracts away virtually nothing away from TCPServer to allow for maximum extensibility.
Anything at the TCP level and higher, such as raw HTTP, is fair game for Mooro!
Extending Mooro is quite simple because it is
* **Compact**. The base server has 0 dependencies and fits in less than 150 lines of code(this number _includes_ comments)!
* **Pure Ruby**. No C extensions, so you don't need to dive into the shadow realm to figure out the internals of Mooro.
* **Almost GServer compatible**. Most of the server interface is identical to [GServer](https://github.com/ruby/gserver), an ex-stdlib Generic Server, for familiarity's sake.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

## Usage

If you want to create a basic server that outputs the time,
```ruby
class TimeServer < Mooro::Server
  def serve(io)
    io.puts(Time.now.to_i)
  end
end

server = TimeServer.new(max_connections = 4)
server.start
sleep(15)
server.stop
```

Mooro ships with an implementation of an HTTP Server.
A healthcheck server like [this](https://www.mikeperham.com/2023/09/11/ruby-http-server-from-scratch/) can be built with
```ruby
Http = Mooro::Impl::Http

class HealthCheck < Http::Server
  def handle_request(req)
    req.path == "/" ? Http::Response[200] : Http::Response[404]
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Mooro is in desperate need of Tests (both Unit and Integration) and Benchmarks.
I unfortunately lack the expertise needed for either of these, so any contribution in these areas are greatly appreciated.
Contributions outside these areas are, of course, also welcome.

Bug reports and pull requests are welcome on GitHub at https://github.com/Forthoney/mooro. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/Forthoney/mooro/blob/main/CODE_OF_CONDUCT.md).

## Caveats

* `Ractor`s are still experimental as of `3.2.2`. Subsequently, Mooro should be treated as experimental.

* Mooro is quite incompatible with older versions of Ruby. Anything pre-`Ractor` (i.e. pre 3.0) obviously does not work.
The builtin HTTP Server requires Ruby 3.2 or later, although this can easily be circumvented if need be.

* Mooro's interface is not exactly like `gserver`. Read more [here](docs/gserver_differences.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Mooro project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/Forthoney/mooro/blob/main/CODE_OF_CONDUCT.md).
