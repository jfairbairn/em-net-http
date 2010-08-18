$: << '.'
require File.dirname(__FILE__) + '/em-net-http'

EM.run do
  Fiber.new do
    Net::HTTP.start('encrypted.google.com', :use_ssl=>true, :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
      res = http.get('/search?q=james')
      puts res.body
    end
    EM.stop_event_loop
  end.resume
end