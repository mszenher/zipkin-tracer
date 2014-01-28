require 'faraday'
require 'zipkin-tracer/intra_process_trace_id'

# This middleware adds cross-application tracing data to each outgoing request made by Faraday.
#
module ZipkinTracer
    class FaradayHandler < ::Faraday::Middleware

      def initialize(app, init = {})
        @logger = init[:logger]
        
        super(app)
      end

      def call(env)
        begin
          id = ZipkinTracer::IntraProcessTraceId.current

          env[:request_headers]['X-B3-Traceid'] ||= id.trace_id.to_s
          env[:request_headers]['X-B3-Spanid'] ||= id.span_id.to_s
          env[:request_headers]['X-B3-Parentid'] ||= id.parent_id.to_s
          env[:request_headers]['X-B3-Sampled'] ||= id.sampled.to_s
        rescue # Rescue everything!  The call must go on!
          # TODO:  log a nice error message here
        end
        
        @app.call(env)
      end

    end
end
