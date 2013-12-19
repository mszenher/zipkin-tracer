require 'faraday'

# This middleware adds cross-application tracing data to each outgoing request made by Faraday.
#
module ZipkinTracer
    class FaradayHandler < ::Faraday::Middleware

      def initialize(app)
        super(app)
      end

      def call(env)
        # TODO:  It would be nice to do this stuff in a nice loop but Faraday doesn't seem to 
        # like the loop.  So in future try again to loop!
        # TODO:  Encapsulate Thread.current[:HTTP_X_B3_TRACEID] and stuff in a class.
        begin
          trace_id = Thread.current[:HTTP_X_B3_TRACEID]
          span_id = Thread.current[:HTTP_X_B3_SPANID]
          parent_id = Thread.current[:HTTP_X_B3_PARENTID]
          sampled = Thread.current[:HTTP_X_B3_SAMPLED]

          env[:request_headers]['X-B3-Traceid'] ||= trace_id.to_s
          env[:request_headers]['X-B3-Spanid'] ||= span_id.to_s
          env[:request_headers]['X-B3-Parentid'] ||= parent_id.to_s
          env[:request_headers]['X-B3-Sampled'] ||= sampled.to_s
        rescue # Rescue everything!  The call must go on!
          # TODO:  log a nice error message here
        end
        
        @app.call(env)
      end

    end
end
