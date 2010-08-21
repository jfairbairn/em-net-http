$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'em-net-http'
require 'time'
require 'spec'
require 'spec/autorun'

require 'mimic'

Spec::Runner.configure do |config|
  config.before(:all) do
    Mimic.mimic do
      Net::HTTPResponse::CODE_TO_OBJ.each do |code, klass|
        get("/code/#{code}").returning("#{code} #{klass.name}", code.to_i, {})
      end
      
      get('/hello').returning('Hello World!', 200, {'Content-Type'=>'text/plain'})
      
      post('/testpost') do
        "You said #{request.body.read}."
      end
    end
  end
  
  config.after(:all) do
    Mimic.cleanup!
  end
end
