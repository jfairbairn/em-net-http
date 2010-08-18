Using the magic of Ruby 1.9's Fibers, we monkeypatch Net::HTTP to use
the faster, nonblocking em-http-request under the hood. Obviously this
will only work from inside the EventMachine event loop.