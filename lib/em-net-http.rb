require 'eventmachine'
require 'addressable/uri'
require 'em-http-request'
require 'net/http'
require 'fiber'

module EventMachine
  class NetHTTPResponse
    include Enumerable
    def each(&blk)
      @header.each(&blk)
    end
    
    attr_reader :code, :body, :header
    
    def initialize(res)
      @code = res.response_header.status.to_s
      @header = res.response_header
      @body = res.response
    end
    
    def [](k)
      @header[key(k)]
    end
    
    def key?(k)
      @header.key? key(k)
    end
    
    def read_body(dest=nil,&block)
      @body
    end
    
    private
    def key(k)
      k.upcase.tr('-','_')
    end
    
  end
end
  

module Net
  class HTTP
    def request(req, body = nil, &block)
      uri = Addressable::URI.parse("#{use_ssl? ? 'https://' : 'http://'}#{addr_port}#{req.path}")
      req = EM::HttpRequest.new(uri).send(req.class::METHOD.downcase.to_sym)
      f=Fiber.current
      req.callback {|res|f.resume(EM::NetHTTPResponse.new(res))}
      res = Fiber.yield
      yield res if block_given?
      res
    end
    
  end
end

