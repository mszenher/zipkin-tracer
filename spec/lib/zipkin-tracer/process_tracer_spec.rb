require 'spec_helper'
require 'zipkin-tracer/process_tracer'

describe ZipkinTracer::ProcessTracer do
  before { 
    # Need to stub this b/c we aren't talking to a live Zipkin collector in these tests.
    ::Trace.stub(:default_endpoint)
    ::Trace.stub_chain(:default_endpoint, :service_name=) 
  }
  let(:config_args) { {
    service_name: 'Test Service', 
    scribe_server: 'test-server:8080'
  } }
  let(:tracer) { ZipkinTracer::ProcessTracer }

  describe '#configure' do
    it 'initializes a trace' do
      tracer.configure(config_args).should be_a(Trace::ZipkinTracer)
    end

    it 'requires a service name' do
      expect { tracer.configure({scribe_server: 'test-server:8080'}) }.to raise_error
    end

    it 'requires a scribe server' do
      expect { tracer.configure({service_name: 'Test Service'}) }.to raise_error
    end
  end

  describe '#configure_sample_rate' do
    context 'when declared' do
      context 'when greater than 1.0 or less than 0.0' do
        it('raises an error') { expect { tracer.configure(config_args.merge({sample_rate: -1.0})) }.to raise_error }
        it('raises an error') { expect { tracer.configure(config_args.merge({sample_rate: 1.1})) }.to raise_error }
      end

      context 'when between 0.0 and 1.0' do
        it 'returns the declared value' do 
          tracer.configure(config_args.merge({sample_rate: 0.5}))
          tracer.instance_variable_get("@sample_rate").should eq(0.5)
        end
      end
    end

    context 'when undeclared' do
      it 'uses a default rate' do
        tracer.configure(config_args)
        tracer.instance_variable_get("@sample_rate").should eq(0.1)
      end
    end
  end

  describe 'trace processes' do
    let(:rpc_name) { 'some work' }
    let(:process) { 'worker' }
    before { tracer.configure(config_args) }

    describe '#start_new_trace' do
      it 'instantiates a new TRACEID' do
        tracer.start_new_trace(rpc_name, process)
        Thread.current['TRACEID'].should_not be_nil
      end

      it 'instantiates a new SPANID' do
        tracer.start_new_trace(rpc_name, process)
        Thread.current['SPANID'].should_not be_nil
      end

      it 'pushes the trace id to the trace' do
        Trace.should_receive(:push).with an_instance_of(Trace::TraceId)
        tracer.start_new_trace(rpc_name, process)
      end

      it 'yields to the block and stops tracing once the block is finished' do
        Object.should receive(:inspect)
        Trace.should receive(:pop)
        tracer.trace_child(rpc_name, process) { Object.inspect }
      end
    end

    describe '#trace_internal_process' do
      before { tracer.start_new_trace(rpc_name, process) }

      it 'uses the current TRACEID as TRACEID' do
        traceid = Thread.current['TRACEID']
        tracer.trace_internal(rpc_name, process) 
        Thread.current['TRACEID'].should eq(traceid)
      end

      it 'does not use a PARENTID' do
        tracer.trace_internal(rpc_name, process) 
        Thread.current['PARENTID'].should be_nil
      end

      it 'creates a new SPANID' do
        spanid = Thread.current['SPANID']
        tracer.trace_internal(rpc_name, process) 
        Thread.current['SPANID'].should_not eq(spanid)
      end
    end

    describe '#trace_child' do
      before { tracer.start_new_trace(rpc_name, process) }

      it 'uses the current TRACEID as TRACEID' do
        traceid = Thread.current['TRACEID']
        tracer.trace_child(rpc_name, process) 
        Thread.current['TRACEID'].should eq(traceid)
      end

      it 'updates PARENTID using the current SPANID' do
        spanid = Thread.current['SPANID']
        tracer.trace_child(rpc_name, process) 
        Thread.current['PARENTID'].should eq(spanid)
      end

      it 'creates a new SPANID' do
        spanid = Thread.current['SPANID']
        tracer.trace_child(rpc_name, process) 
        Thread.current['SPANID'].should_not eq(spanid)
      end

      it 'pushes the trace id to the trace' do
        Trace.should_receive(:push).with an_instance_of(Trace::TraceId)
        tracer.trace_child(rpc_name, process)
      end

      it 'yields to the block and stops tracing once the block is finished' do
        Object.should receive(:inspect)
        Trace.should receive(:pop)
        tracer.trace_child(rpc_name, process) { Object.inspect }
      end
    end
  end
end
