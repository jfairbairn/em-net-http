$: << '.'
require File.dirname(__FILE__) + '/em-net-http'
require 'weary'

module Weary
  class Response
    def content_type ; @content_type.split(';').first ; end
    
    def value ; self ; end
  end
 
  class Request
    def perform!(&block)
      @on_complete = block if block_given?
      before_send.call(self) if before_send
      req = http.request(request)
      response = Response.new(req, self)
      if response.redirected? && follows?
        response.follow_redirect
      else
        on_complete.call(response) if on_complete
        response
      end
    end
  end
end

EM.run do
  Fiber.new do
    class TwitterUser < Weary::Base
        domain "http://twitter.com/users/"

        get "show" do |resource|
            resource.with = [:id, :user_id, :screen_name]
        end
    end

    user = TwitterUser.new
    me = user.show(:id => "jfairbairn").perform
    puts me['status']['text']
    
    EM.stop_event_loop
  end.resume
end