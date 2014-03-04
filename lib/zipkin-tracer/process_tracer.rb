require 'zipkin-tracer'
require 'finagle-thrift'
require 'finagle-thrift/trace'
require 'scribe'
require 'rack/careless_scribe'
require 'base64'

module ZipkinTracer extend self
  class ProcessTracer
    attr_accessor :service_name, :service_port, :sample_rate, :scribe, :scribe_max_buffer

    class << self
      def configure(config = {})
        raise ::ArgumentError.new('You must provide a service_name in your config') unless config[:service_name]
        @service_name = config[:service_name]
        raise ::ArgumentError.new('You must provide a scribe_server in your config') unless config[:scribe_server]
        @scribe = config[:scribe_server] ? Scribe.new(config[:scribe_server]) : Scribe.new()
        @service_port = config[:service_port]
        @scribe_max_buffer = config[:scribe_max_buffer] ? config[:scribe_max_buffer] : 10
        configure_sample_rate(config[:sample_rate])

        ::Trace.tracer = ::Trace::ZipkinTracer.new(CarelessScribe.new(@scribe), @scribe_max_buffer)
      end

      def start_new_trace(rpc_name, process, &block)
        trace_id = Trace::TraceId.new(*trace_parameters)
        record(trace_id, rpc_name, process, &block)
      end

      def trace_internal(rpc_name, process, &block)
        if ZipkinTracer::IntraProcessTraceId.current
          trace_id = Trace::TraceId.new(*trace_parameters([current_trace_trace_id]))
          record(trace_id, rpc_name, process, &block)
        end
      end
      
      def trace_child(rpc_name, process, &block)
        # REVIEW: Raise an error if there is no current trace
        #
        if ZipkinTracer::IntraProcessTraceId.current # Can only trace internal processes if there is already an existing trace
          trace_id = Trace::TraceId.new(*trace_parameters([current_trace_trace_id, current_trace_span_id]))
          record(trace_id, rpc_name, process, &block)
        end
      end

      # Sample rate can be reconfigured
      # TODO: Needs tests, especially for efficacy
      #
      def configure_sample_rate(configured_sample_rate = nil)
        @sample_rate = if configured_sample_rate && (configured_sample_rate < 0.0 || configured_sample_rate > 1.0)
          raise ::ArgumentError.new('Sample rate must be between 0.0 and 1.0')
        else
          configured_sample_rate ? configured_sample_rate : 0.1
        end
      end

      private
 
      def current_trace_trace_id
        ZipkinTracer::IntraProcessTraceId.current.trace_id
      end

      def current_trace_span_id
        ZipkinTracer::IntraProcessTraceId.current.span_id
      end

      def trace_parameters(params = [])
        [
          params[0] || Trace.generate_id,	# TRACEID
          params[1],				# PARENTID
          Trace.generate_id,			# SPANID
          @sample_rate,				# SAMPLE_RATE
          1					# FLAGS
        ]
      end

      def record(trace_id, rpc_name, process, &block)
        ZipkinTracer::IntraProcessTraceId.current = trace_id

        ::Trace.push(trace_id)
        ::Trace.set_rpc_name(rpc_name) 
        # REVIEW: Naming for the internal method or process, which is useful but not necessarily correct
        ::Trace.default_endpoint.service_name = "#{@service_name} #{process}"
        ::Trace.record(::Trace::BinaryAnnotation.new('process', process, "STRING", ::Trace.default_endpoint))
        ::Trace.record(::Trace::Annotation.new(::Trace::Annotation::SERVER_RECV, ::Trace.default_endpoint))
      
        yield if block_given?
      
        ::Trace.record(::Trace::Annotation.new(::Trace::Annotation::SERVER_SEND, ::Trace.default_endpoint))
        ::Trace.pop
        ::Trace.default_endpoint.service_name = @service_name # Set it back to the service name
      end
    end
  end
end
