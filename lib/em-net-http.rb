require 'eventmachine'
require 'addressable/uri'
require 'em-http-request'
require 'net/http'
require 'fiber'

module EventMachine
  class NetHTTPResponse
    attr_reader :code, :body, :header, :message, :http_version
    alias_method :msg, :message
    
    def initialize(res)
      @code = res.response_header.http_status
      @message = res.response_header.http_reason
      @http_version = res.response_header.http_version
      @header = res.response_header
      @body = res.response
    end
    
    def content_type
      self['content-type']
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
    
    def to_hash
      h={}
      @header.each do |k, v|
        h[fromkey(k)] = v
      end
      h
    end
      
    private
    def key(k)
      k.upcase.tr('-','_')
    end
    
    def fromkey(k)
      k.tr('_', '-').split('-').map{|i|i.capitalize}.join('-')
    end
    
    include Enumerable
    def each(&blk)
      @header.each(&blk)
    end
    
  end
end
  

module Net
  class HTTP
    def request(req, body = nil, &block)
      f=Fiber.current
      uri = Addressable::URI.parse("#{use_ssl? ? 'https://' : 'http://'}#{addr_port}#{req.path}")
      body = body || req.body
      opts = body.nil? ? {} : {:body => body}
      if use_ssl?
        sslopts = opts[:ssl] = {}
        sslopts[:verify_peer] = verify_mode == OpenSSL::SSL::VERIFY_PEER
        sslopts[:private_key_file] = key if key
        sslopts[:cert_chain_file] = ca_file if ca_file
      end
      headers = opts[:head] = {}
      req.each do |k, v|
        headers[k] = v
      end
      headers['content-type'] ||= "application/x-www-form-urlencoded"
      httpreq = EM::HttpRequest.new(uri).send(req.class::METHOD.downcase.to_sym, opts)
      httpreq.callback {|res|f.resume(EM::NetHTTPResponse.new(res))}
      httpreq.errback {|res|f.resume(EM::NetHTTPResponse.new(res))}
      res = Fiber.yield
      yield res if block_given?
      res
    end
    
  end
end

# Other bits and bobs.


