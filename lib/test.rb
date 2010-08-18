$: << '.'
require File.dirname(__FILE__) + '/em-net-http'

EM.run do
  Fiber.new do
    http = Net::HTTP.new('www.google.com') 
    http.start do |http|
      res = http.get('/search?q=james')
      puts res.body
    end
    EM.stop_event_loop
  end.resume
end