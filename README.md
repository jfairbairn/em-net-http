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

I have vaguely tested <tt>em-net-http</tt> with <tt>[right_aws][3]</tt>,
[Weary][4] and the [Tumblr gem][5]. There's no actual unit tests as such; if you're
feeling smarter than I am, please feel free to contribute some! <tt>:-)</tt>

### Caveat

The <tt>Net::HTTP</tt> API is a many-headed hydra -- I haven't patched much of it;
in fact I've patched <tt>Net::HTTP#request</tt>, and that's it. Your mileage may
therefore vary. Please feed me patches, pull requests and bug reports!

[1]: http://github.com/igrigorik/em-http-request
[2]: http://rubyeventmachine.com/
[3]: http://rightaws.rubyforge.org/
[4]: http://github.com/mwunsch/weary
[5]: http://github.com/mwunsch/tumblr