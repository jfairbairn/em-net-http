Most Ruby web API libraries use <tt>Net::HTTP</tt> (because it's ubiquitous),
but I want to use them in my non-blocking EventMachine-based applications, and
I don't want Net::HTTP to block. I therefore wrote this.

Using the magic of Ruby 1.9's Fibers, we monkeypatch <tt>Net::HTTP</tt> to use
the faster, nonblocking <tt>[em-http-request][1]</tt> under the hood. Obviously this
will only work from inside the [EventMachine][2] event loop, and from within a spawned
fiber:

    require 'em-net-http'

    EM.run do
      Fiber.new do
        Net::HTTP.start('encrypted.google.com', :use_ssl=>true) do |http|
          res = http.get('/search?q=james')
          puts res.body
        end
        EM.stop_event_loop
      end.resume
    end
    
The above will run without blocking your carefully-tuned nonblocking webapp.

There are a few tests (taking advantage of Luke Redpath's very useful [Mimic][6] gem)
that assert that responses are identical to those created by <tt>Net::HTTP</tt>.
These are by no means exhaustive; if you're using <tt>Net::HTTP</tt> in some other way
and the <tt>em-net-http</tt>'s behaviour is not what you expect, do send me a failing test
case.

Currently tested with Ruby (MRI) 1.9.1 and 1.9.2.

### Caveat

The <tt>Net::HTTP</tt> API is a many-headed hydra -- I haven't patched much of it;
in fact I've patched <tt>Net::HTTP#request</tt>, and that's it. Your mileage may
therefore vary. Please feed me patches, pull requests and bug reports!

[1]: http://github.com/igrigorik/em-http-request
[2]: http://rubyeventmachine.com/
[3]: http://rightaws.rubyforge.org/
[4]: http://github.com/mwunsch/weary
[5]: http://github.com/mwunsch/tumblr
[6]: http://github.com/lukeredpath/mimic