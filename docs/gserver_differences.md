# Differences with GServer
Although Mooro is based off of the GServer interface, there exists some differences.
Most are ergonomic differences (at least for the end user) but there are small functionality differences as well.

## Logging
Logging is turned on in Mooro, whereas you need to turn it on for GServer.
The default Server does not allow for turning it off, but there is nothing technically stopping anyone from turning it off.
This is more of a "I got a bit lazy" portion - I would appreciate contributions that enable this easily!

## Multiserver Management
GServer comes built with multiserver management.
Mooro does not, and does not intend to, at least in the base Server.
There is, of course, the question of how. This is nontrivial but also not impossible.
More importantly, I feel multiserver management disregards Mooro's leanness principle.
My unsubstantiated opinion is that if you really have need for that multiserver management, Mooro is too light for you.
I am very very open to being proven wrong, and when proven wrong, will write a `Plugin::Multiserver`.

## Tests and Benchmarks
One of the [reasons](https://bugs.ruby-lang.org/issues/5480) why `gserver` was removed from stdlib was due to a lack of tests.
Mooro would _like_ to be different from GServer by having adequate tests and benchmarks.
