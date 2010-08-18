$: << File.dirname(__FILE__)
require 'em-net-http'
require 'weary'
require 'em-net-http/weary'

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