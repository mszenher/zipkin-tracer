# Copyright 2012 Twitter Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'finagle-thrift'
require 'finagle-thrift/trace'
require 'scribe'
require 'rack/careless_scribe'

module ZipkinTracer extend self

  class RackHandler
    B3_HEADERS = %w[HTTP_X_B3_TRACEID HTTP_X_B3_PARENTSPANID HTTP_X_B3_SPANID HTTP_X_B3_SAMPLED]
    
    attr_accessor :service_name, :service_port, :sample_rate
    
    def initialize(app, init = {})
      @app = app
      @lock = Mutex.new

      # Use app.config.zipkin_tracer if available; otherwise use init arg.
      if app.respond_to?(:config) && app.config.respond_to?(:zipkin_tracer)
        config = app.config.zipkin_tracer
      else
        config = init
      end

      raise ::ArgumentError.new('config must be a hash') unless config.is_a?(Hash)
      
      raise ::ArgumentError.new('You must provide a service_name in your config') unless config[:service_name]
      @service_name = config[:service_name]
      raise ::ArgumentError.new('You must provide a service_port in your config') unless config[:service_port]
      @service_port = config[:service_port]

      scribe =
        if config[:scribe_server] then
          Scribe.new(config[:scribe_server])
        else
          Scribe.new()
        end

      scribe_max_buffer =
        if config[:scribe_max_buffer] then
          config[:scribe_max_buffer]
        else
          10
        end

      if config[:sample_rate] && (config[:sample_rate] < 0.0 || config[:sample_rate] > 1.0)
        raise ::ArgumentError.new('Sample rate must be between 0.0 and 1.0')
      end
      
      @sample_rate =
        if config[:sample_rate] then
          config[:sample_rate]
        else
          0.1
        end

      ::Trace.tracer = ::Trace::ZipkinTracer.new(CarelessScribe.new(scribe), scribe_max_buffer)
    end

    def call(env)
      id = get_or_create_trace_id(env)
      
      begin
        ::Trace.default_endpoint = ::Trace.default_endpoint.with_service_name(@service_name).with_port(@service_port)
      rescue => e
        @logger.warn 'Cannot connect to scribe service' if @logger
      end
      
      ::Trace.sample_rate=(@sample_rate)
    
      # pass zipkin cross application trace variables to consuming application
      # so it can pass them on in turn if it makes more requests
      Thread.current['HTTP_X_B3_TRACEID'] = id.trace_id
      Thread.current['HTTP_X_B3_PARENTSPANID'] = id.parent_id
      Thread.current['HTTP_X_B3_SPANID'] = id.span_id
      Thread.current['HTTP_X_B3_SAMPLED'] = id.sampled

      # TODO: Nothing wonky that the tracer does should stop us from calling the app!!!
      tracing_filter(id, env) { @app.call(env) }
    end

    private
    def tracing_filter(trace_id, env)
      @lock.synchronize do
        begin
          ::Trace.push(trace_id)
          ::Trace.set_rpc_name(env["REQUEST_METHOD"]) # get/post and all that jazz
          ::Trace.record(::Trace::BinaryAnnotation.new("http.uri", env["PATH_INFO"], "STRING", ::Trace.default_endpoint))
          ::Trace.record(::Trace::Annotation.new(::Trace::Annotation::SERVER_RECV, ::Trace.default_endpoint))
        rescue # Nothing wonky that the tracer does should stop us from calling the app!!!
          # TODO:  probably nice to log something here
        end
      end
      yield if block_given?
    ensure
      @lock.synchronize do
        begin
          ::Trace.record(::Trace::Annotation.new(::Trace::Annotation::SERVER_SEND, ::Trace.default_endpoint))
          ::Trace.pop
        rescue # Nothing wonky that the tracer does should stop us from calling the app!!!
          # TODO:  probably nice to log something here
        end
      end
    end

    def get_or_create_trace_id(env)
      trace_parameters = begin
        if (B3_HEADERS - %w(HTTP_X_B3_PARENTSPANID)).all? { |key| env.has_key?(key) }
          [
            env['HTTP_X_B3_TRACEID'],
            env['HTTP_X_B3_SPANID'],
            Trace.generate_id,
            env['HTTP_X_B3_SAMPLED']
          ] # span becomes parent and generate new span id
        else
          new_id = Trace.generate_id
          [new_id, nil, new_id, should_sample?]
        end
      end
      trace_parameters[3] = ["true", true, :true].include?(trace_parameters[3]) ? true : false # this is the "sampled" param
      trace_parameters[4] = 1 # this is the flags param
      
      # trace_params = [trace_id, parent_id, span_id, sampled, flags]
      Trace::TraceId.new(*trace_parameters)
    end
    
    # Probabalisticially decide if a trace should be sampled, based on the sample rate.
    # Returns a boolean indicating whether sampling should take place or not.
    def should_sample?
      rand < sample_rate
    end
    
  end
end
