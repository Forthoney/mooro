# Differences with GServer
Although Mooro is based off of the GServer interface, there exists some differences.
Most are ergonomic differences (at least for the end user) but there are small functionality differences as well.

## Logging
Logging is turned on in Mooro, whereas you need to turn it on for GServer.
The default Server does not allow for turning it off, but there is nothing technically stopping anyone from turning it off.
This is more of a "I got a bit lazy" portion - I would appreciate contributions that enable this easily!

## Server#serve vs Server.serve
In GServer, the serve method is overridden as an instance method.
In Mooro, it must be overridden as a class method.
To the end user, this should be a pretty straightforward change, but internally, the story is more complicated.
Ractors cannot use instance methods of the Server class without some tricks.
Using a class method is pretty well defined, however.
Mooro therefore requests the user changes a couple lines rather than introducing unnecessary complexity to Mooro.

## Multiserver Management
GServer comes built with multiserver management.
Mooro does not, and does not intend to, at least in the base Server.
There is, of course, the question of how. This is nontrivial but also not impossible.
More importantly, I feel multiserver management disregards Mooro's leanness principle.
My unsubstantiated opinion is that if you really have need for that multiserver management, Mooro is too light for you.
I am very very open to being proven wrong, and if proven wrong, will write a `Impl::Multiserver`.

## Tests and Benchmarks
Mooro would _like_ to be different from GServer by having adequate tests and benchmarks.
