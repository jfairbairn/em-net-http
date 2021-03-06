$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'em-net-http'
require 'time'
require 'rspec'
require 'mimic'

describe "em-net-http" do
  around(:each) do |example|
    Fiber.new do
      example.run
    end.resume
  end

  describe '' do
    before(:all) do
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

    it 'should support streaming the response' do
      assert_identical(true) {
        body = StringIO.new '', 'wb'

        Net::HTTP.start('localhost', Mimic::MIMIC_DEFAULT_PORT) do |http|
          http.request_get "/image" do |resp|
            resp.should be_a_kind_of(Net::HTTPOK)
            resp.read_body { |chunk| body.write chunk }
            resp
          end
        end.tap do |resp|
          resp.instance_variable_set :@streamed_body, body.string
        end
      }
    end

    it 'should support buffering the response' do
      assert_identical {
        Net::HTTP.start('localhost', Mimic::MIMIC_DEFAULT_PORT) do |http|
          respone = http.request_get "/image" do |resp|
            resp.should be_a_kind_of(Net::HTTPOK)
            resp.read_body # force reading the body before the test tears down the EM loop
            resp
          end
          respone.tap { respone.should be_a_kind_of(Net::HTTPOK) }
        end
      }
    end

    describe 'should be compatible' do
      it 'with Net::HTTP.get()' do
        run_requests {Net::HTTP.get(URI.parse("http://localhost:#{Mimic::MIMIC_DEFAULT_PORT}/hello"))}
        @expected_res.should == @actual_res
      end

      # it 'for Net::HTTP.get_print()' do
      #   run_requests {Net::HTTP.get_print(URI.parse('http://localhost/hello'))}
      #   @expected_res.should == @actual_res
      # end

      # We don't test responses like 100 Continue at the moment.
      %w(200 201 202 203 204 205 206 300 301 302 303 307 400 401 402 403 404 405 406 407 408 409 410 411 412 413 414 415 416 417 500 501 502 503 504 505).each do |code|
        it "with Net::HTTP.start(host, port, &block) with response code #{code}" do
          assert_identical {
            Net::HTTP.start('localhost', Mimic::MIMIC_DEFAULT_PORT) do |http|
              http.get("/code/#{code}").tap { |resp|
                # Force the response to be buffered while we are still in the EM loop, since we shut it down EM before the verifications
                resp.body
              }
            end
          }
        end

        it "with Net::HTTP.new(host, port).start(&block) with response code #{code}" do
          assert_identical {
            h = Net::HTTP.new('localhost', Mimic::MIMIC_DEFAULT_PORT)
            h.start do |http|
              http.get("/code/#{code}")
            end
          }
        end
      end

      it "with response code 304" do
        assert_identical {
          Net::HTTP.start('localhost', Mimic::MIMIC_DEFAULT_PORT) do |http|
            req = Net::HTTP::Get.new('/code/304')
            req['If-Modified-Since'] = Time.now.rfc2822
            http.request(req)
          end
        }

      end

      it 'with post' do
        assert_identical {
          Net::HTTP.start('localhost', Mimic::MIMIC_DEFAULT_PORT) do |http|
            req = Net::HTTP::Post.new('/testpost')
            req.body = 'hello mimic'
            http.request(req)
          end
        }

      end

    end



    after(:all) do
      Mimic.cleanup!
    end

  end

  it 'should raise relevant exceptions' do
    EM.run do
      Fiber.new do
        begin
          Net::HTTP.start('localhost', 1) do |r|
            r.get('/')
          end
          fail('expected exception to be raised')
        rescue => expected
          expected.class.should == Errno::ECONNREFUSED
          EM.stop_event_loop
        end
      end.resume
    end
  end

  def run_requests(&block)
    @expected_res = yield
    EM.run do
      Fiber.new do
        @actual_res = yield
      end.resume
      EM.add_periodic_timer(0.0) do
        EM.stop_event_loop if @actual_res
      end
    end
  end

  def assert_identical(streamed=false, &block)
    run_requests(&block)
    @actual_res.should be_a_kind_of(Net::HTTPResponse)
    @actual_res.should match_response(@expected_res, streamed)
  end

  def match_response(expected, streamed=false)
    ResponseMatcher.new(expected, streamed)
  end

  class ResponseMatcher
    def initialize(expected, streamed=false)
      @expected = expected
      @streamed = streamed
    end

    def matches?(actual)
      # Dates could differ slightly :(
      expected_date = Time.parse(@expected.delete('date').join)
      actual_date = Time.parse(actual.delete('date').join)
      actual_date.should >= expected_date
      actual_date.should <= expected_date + 2

      actual.class.should == @expected.class
      actual.code.should == @expected.code
      actual.to_hash.should == @expected.to_hash.merge({"connection" => ['close']})

      if @streamed
        actual.instance_variable_get(:@streamed_body).should ==
          @expected.instance_variable_get(:@streamed_body)
      else
        actual.body.should == @expected.body
      end
      true
    end

  end
end
