# This extension to Net:HTTP allows us to send Zipkin Tracer variables (stored in Thread.current)
# in headers in every request made from the consuming application.  This of course assumes that the
# consuming application is using Net:HTTP as its HTTP client.
#
if defined?(Net) && defined?(Net::HTTP)
  class Net::HTTP
    # Instrument outgoing HTTP requests
    #
    # If request is called when not the connection isn't started, request
    # will call back into itself (via a start block).
    #
    # Don't tracing until the inner call then to avoid double-counting.
    def request_with_zipkin_trace(request, *args, &block)
      if started?
        Thread.current.keys.each do |thread_key|
          if thread_key.to_s.start_with?('HTTP_X_B3')
            request[thread_key.to_s.gsub('HTTP_', '')] = Thread.current[thread_key].to_s
          end
        end
        request_without_zipkin_trace( request, *args, &block )
      else
        request_without_zipkin_trace( request, *args, &block )
      end
    end

    alias request_without_zipkin_trace request
    alias request request_with_zipkin_trace
  end
end
