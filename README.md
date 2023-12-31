# Mooro: A truly parallel server for CRuby
Mooro is a Ractor-based, compact, parallel TCP server targeting CRuby. It is built to be extended - you can only do so much with raw TCP sockets - and offers straigtforward ways (and examples) of doing so.

## Uncompromising Minimalism
Mooro aims to deliver all essential features expected from a modern Ruby web server such as
* **Parallelism**. Mooro utilizes true parallelism with CRuby through `Ractor`s.
* **Logging**. Supervisor start/stop, worker errors, and other notable events are logged by default, and adding additional logging points is as straightforward as adding `logger.send("message")`.
* **Stopping**. Capable of gracefully stopping (or forcefully, if you prefer that).

At the same time, it abstracts virtually nothing away from TCPServer, enabling maximum extensibility.
Anything at the TCP level and higher is fair game for Mooro.
Extending Mooro is quite simple because it is
* **Compact**. The base server has 0 dependencies and fits in less than 150 lines of code. Yes, this number _includes_ comments!
* **Pure Ruby**. No C extensions, so you don't need to dive into the shadow realm to figure out the internals of Mooro.
* **Almost GServer compatible**. Most of the server interface is identical to [GServer](https://github.com/ruby/gserver), an ex-stdlib Generic Server, for familiarity's sake.

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
A [healthcheck server](https://www.mikeperham.com/2023/09/11/ruby-http-server-from-scratch/) can be built with
```ruby
HTTP = Mooro::Plugin::HTTP

class HealthCheck < Mooro::Server
  include HTTP

  def handle_request(req)
    req.path == "/" ? HTTP::Response[200] : HTTP::Response[404]
  end
end
```

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add mooro

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install mooro



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Mooro is in desperate need of **Tests** (both Unit and Integration) and **Benchmarks**.
I unfortunately lack the expertise needed for thoroughly handling these, so any contribution in these areas are greatly appreciated.
Furthermore, another, more practicality focused priority is the **rack-ification** of Mooro.
[Rack](https://github.com/rack/rack) is undoubtedly the gold standard interface for HTTP applications.
Mooro is technically fully capable of supporting Rack, but the big hurdle currently is properly parsing HTTP requests (yuck).

Contributions outside these areas are, of course, also welcome.

Bug reports and pull requests are welcome on GitHub at https://github.com/Forthoney/mooro. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/Forthoney/mooro/blob/main/CODE_OF_CONDUCT.md).

## Caveats

* `Ractor`s are still experimental as of `3.2.2`. Subsequently, Mooro should be treated as experimental.

* Mooro is quite incompatible with older versions of Ruby. Anything pre-`Ractor` (i.e. pre 3.0) obviously does not work.
The builtin HTTP Server requires Ruby 3.2 or later, although this can easily be circumvented if need be.

* Mooro's interface is not exactly like `gserver`. Read more about the differences [here](docs/gserver_differences.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Mooro project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/Forthoney/mooro/blob/main/CODE_OF_CONDUCT.md).
