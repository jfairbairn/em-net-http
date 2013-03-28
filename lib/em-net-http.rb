require 'eventmachine'
require 'addressable/uri'
require 'em-http-request'
require 'net/http'
require 'fiber'

module EventMachine
  module NetHTTP
    class Response
      attr_reader :code, :body, :header, :message, :http_version
      alias_method :msg, :message

      def initialize(response_header)
        @code = response_header.http_status.to_s
        @message = response_header.http_reason
        @http_version = response_header.http_version
        @header = response_header
      end

      def set_body body
        @already_buffered = true
        @body = body
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
end


module Net
  class HTTPResponse
    class << self
      public :response_class
    end

    alias_method :orig_net_http_read_body, :read_body

    def read_body(dest=nil, &block)
      return @body if @already_buffered
      return orig_net_http_read_body(dest, &block) unless ::EM.reactor_running?
      if block_given?
        f = Fiber.current
        @httpreq.callback { |res| f.resume }
        @httpreq.stream &block
        Fiber.yield
      else
        unless @body || @already_buffered
          if self.class.body_permitted?
            f = Fiber.current
            io = StringIO.new '', 'wb'
            io.set_encoding 'ASCII-8BIT'
            @httpreq.callback { |res| f.resume io.string }
            @httpreq.errback { |err| f.resume err }
            @httpreq.stream { |chunk| io.write chunk }
            @body = Fiber.yield
          end
          @already_buffered = true
        end
        @body
      end
    end
  end

  class HTTP
    alias_method :orig_net_http_request, :request

    alias_method :orig_net_http_do_start, :do_start

    def do_start

      return orig_net_http_do_start unless ::EM.reactor_running?

      @started = true
    end

    def request(req, body = nil, &block)

      return orig_net_http_request(req, body, &block) unless ::EM.reactor_running?

      uri = Addressable::URI.parse("#{use_ssl? ? 'https://' : 'http://'}#{addr_port}#{req.path}")

      body = body || req.body
      opts = body.nil? ? {} : {:body => body}
      if use_ssl?
        sslopts = opts[:ssl] = {}
        sslopts[:verify_peer] = verify_mode == OpenSSL::SSL::VERIFY_PEER
        sslopts[:private_key_file] = key if key
        sslopts[:cert_chain_file] = ca_file if ca_file
      end
      opts[:timeout] = self.read_timeout

      headers = opts[:head] = {}
      req.each do |k, v|
        headers[k] = v
      end

      headers['content-type'] ||= "application/x-www-form-urlencoded"

      t0 = Time.now
      httpreq = EM::HttpRequest.new(uri).send(req.class::METHOD.downcase.to_sym, opts)

      f=Fiber.current

      convert_em_http_response = lambda do |res|
        emres = EM::NetHTTP::Response.new(res.response_header)
        emres.set_body res.response
        nhresclass = Net::HTTPResponse.response_class(emres.code)
        nhres = nhresclass.new(emres.http_version, emres.code, emres.message)
        emres.to_hash.each do |k, v|
          nhres.add_field(k, v)
        end
        nhres.body = emres.body if req.response_body_permitted? && nhresclass.body_permitted?
        nhres.instance_variable_set '@read', true
        f.resume nhres
      end


      if block_given?
        httpreq.headers { |headers|

          emres = EM::NetHTTP::Response.new(headers)
          nhresclass = Net::HTTPResponse.response_class(emres.code)
          nhres = nhresclass.new(emres.http_version, emres.code, emres.message)
          emres.to_hash.each do |k, v|
            nhres.add_field(k, v)
          end
          f.resume nhres
        }
        httpreq.errback {|err|f.resume(:error)}

        nhres = yield_with_error_check(t0)
        nhres.instance_variable_set :@httpreq, httpreq

        yield nhres
        nhres
      else
        httpreq.callback &convert_em_http_response
        httpreq.errback {|err|f.resume(:error)}

        yield_with_error_check(t0)
      end
    end

    private

    def yield_with_error_check(t0)
      res = Fiber.yield

      if res == :error
        raise 'EM::HttpRequest error - request timed out' if Time.now - self.read_timeout > t0
        raise 'EM::HttpRequest error - unknown error'
      end

      res
    end

  end
end

# Other bits and bobs.


