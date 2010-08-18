module Weary
  class Response
    # Weary doesn't like Content-Type headers with extra bits on the end, like '; encoding=utf-8'.
    def content_type ; @content_type.split(';').first ; end
    
    def value ; self ; end
  end
 
  # Weary runs multi-threaded by default. The thread is spawned in perform!(). Let's not do that.
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
