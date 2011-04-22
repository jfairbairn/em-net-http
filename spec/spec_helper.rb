$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'em-net-http'
require 'time'
require 'rspec'

require 'mimic'

RSpec.configure do |config|
  config.before(:all) do
    Mimic.mimic do
      Net::HTTPResponse::CODE_TO_OBJ.each do |code, klass|
        get("/code/#{code}").returning("#{code} #{klass.name}", code.to_i, {})
      end
      
      get('/hello').returning('Hello World!', 200, {'Content-Type'=>'text/plain'})
      
      class BigImageResponse
        def each
          ::File.open('spec/image.jpg', "rb") { |file|
            while part = file.read(8192)
              yield part
            end
          }
        end
      end
      resp = BigImageResponse.new
      get('/image').returning(resp, 200, {"Content-Type" => 'image/jpeg'})

      post('/testpost') do
        "You said #{request.body.read}."
      end
    end
  end
  
  config.after(:all) do
    Mimic.cleanup!
  end
end
