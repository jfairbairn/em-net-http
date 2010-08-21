require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "em-net-http" do
  describe 'should be compatible' do
    it 'for Net::HTTP.get()' do
      run_requests {Net::HTTP.get(URI.parse('http://localhost/hello'))}
      @expected_res.should == @actual_res
    end

    # it 'for Net::HTTP.get_print()' do
    #   run_requests {Net::HTTP.get_print(URI.parse('http://localhost/hello'))}
    #   @expected_res.should == @actual_res
    # end

    # We don't test responses like 100 Continue at the moment.
    %w(200 201 202 203 204 205 206 300 301 302 303 307 400 401 402 403 404 405 406 407 408 409 410 411 412 413 414 415 416 417 500 501 502 503 504 505).each do |code|
      it "for Net::HTTP.start(host, port, &block) with response code #{code}" do
        assert_identical {
          Net::HTTP.start('localhost', Mimic::MIMIC_DEFAULT_PORT) do |http|
            http.get("/code/#{code}")
          end
        }
      end
  
      it "for Net::HTTP.new(host, port).start(&block) with response code #{code}" do
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
  
  def assert_identical(&block)
    run_requests(&block)
    @actual_res.should match_response(@expected_res)
  end
  
  def match_response(expected)
    ResponseMatcher.new(expected)
  end
  
  class ResponseMatcher
    def initialize(expected)
      @expected = expected
    end
    
    def matches?(actual)
      # Dates could differ slightly :(
      expected_date = Time.parse(@expected.delete('date').join)
      actual_date = Time.parse(actual.delete('date').join)
      actual_date.should >= expected_date
      actual_date.should <= expected_date + 2
      [:class, :code, :to_hash, :body].each do |i|
        actual.send(i).should == @expected.send(i)
      end
      true
    end
    
  end
end
