require 'spec_helper'
require 'zipkin-tracer'

describe ZipkinTracer::RackHandler do
  before(:each) do
    @mocked_app = double
    @mocked_app.stub(:call)
    
    @sample_zipkin_tracer_config = {service_name: 'mccadmin', service_port: 9410, sample_rate: 1, scribe_server: "127.0.0.1:9410"}    
  end
  
  describe 'initialization' do
    
    it 'raises when no config is provided' do
      expect{ ZipkinTracer::RackHandler.new(@mocked_app) }.to raise_error(ArgumentError)
    end

    it 'gets config from app if available' do
      config = double
      @mocked_app.stub(:config).and_return(config)
      config.stub(:zipkin_tracer).and_return(@sample_zipkin_tracer_config)

      @mocked_app.should_receive(:config).and_return(config)
      config.should_receive(:zipkin_tracer).and_return(@sample_zipkin_tracer_config)
      ZipkinTracer::RackHandler.new(@mocked_app)
    end
    
    it 'raises when config is not a hash' do
      config = "blah"
      expect{ ZipkinTracer::RackHandler.new(@mocked_app, config) }.to raise_error(ArgumentError)
    end
    
    [:service_name, :service_port].each do |config_key|
      it 'raises when no #{config_key.to_s} is provided in config' do
        @sample_zipkin_tracer_config.delete(config_key.to_sym)
        expect{ ZipkinTracer::RackHandler.new(@mocked_app) }.to raise_error(ArgumentError)
      end
    end
    
    it 'raise when sample rate is given but less than 0' do
      @sample_zipkin_tracer_config[:sample_rate] = -0.1
      expect{ ZipkinTracer::RackHandler.new(@mocked_app, @sample_zipkin_tracer_config) }.to raise_error(ArgumentError)
    end

    it 'raise when sample rate is given but greater than 1' do
      @sample_zipkin_tracer_config[:sample_rate] = 1.1
      expect{ ZipkinTracer::RackHandler.new(@mocked_app, @sample_zipkin_tracer_config) }.to raise_error(ArgumentError)
    end
    
    it 'sets sample_rate if not configured' do
      @sample_zipkin_tracer_config.delete(:sample_rate)
      rack_zipkin = ZipkinTracer::RackHandler.new(@mocked_app, @sample_zipkin_tracer_config)
      rack_zipkin.sample_rate.should == 0.1
    end
    
    it 'instantiates a new Tracer' do
      ::Trace::ZipkinTracer.should_receive(:new)
      ZipkinTracer::RackHandler.new(@mocked_app, @sample_zipkin_tracer_config)
    end
  end
  
  describe 'call' do
    before do      
      @sample_env = {
        "PATH_INFO"=>"/some_path", 
        "QUERY_STRING"=>"hi=there", 
        "REMOTE_ADDR"=>"127.0.0.1", 
        "REMOTE_HOST"=>"localhost", 
        "REQUEST_METHOD"=>"GET", 
        "REQUEST_URI"=>"http://someexample.org/some_path", 
        "SCRIPT_NAME"=>"", 
        "SERVER_NAME"=>"0.0.0.0", 
        "SERVER_PORT"=>"3000", 
        "SERVER_PROTOCOL"=>"HTTP/1.1", 
        "SERVER_SOFTWARE"=>"WEBrick/1.3.1 (Ruby/1.9.3/2012-11-10)",
        "HTTP_USER_AGENT"=>"curl/7.24.0 (x86_64-apple-darwin12.0) libcurl/7.24.0 OpenSSL/0.9.8r zlib/1.2.5", 
        "HTTP_ACCEPT"=>"*/*", 
        "HTTP_VERSION"=>"HTTP/1.1", 
        "REQUEST_PATH"=>"/some_path", 
        "ORIGINAL_FULLPATH"=>"/some_path", 
      }
      
      @zipkin_tracer = ZipkinTracer::RackHandler.new(@mocked_app, @sample_zipkin_tracer_config)
      ::Trace.stub(:record)
    end
    
    describe 'setting values in Thread.current' do
      before do
        # delete here to ensure that 'call' does what it should in setting Thread.current values
        ZipkinTracer::RackHandler::B3_HEADERS.each do |header_key|
          Thread.current[header_key] = ""
        end
      end
      
      context 'existing trace info' do
        before do
          # Create fake trace params and add them to the env.
          # trace_params = [trace_id, parent_id, span_id, sampled, flags]
          id = Trace::TraceId.new(Trace.generate_id, Trace.generate_id, Trace.generate_id, true, 1)
          @sample_env['HTTP_X_B3_TRACEID'] = id.trace_id
          @sample_env['HTTP_X_B3_PARENTSPANID'] = id.parent_id
          @sample_env['HTTP_X_B3_SPANID'] = id.span_id
          @sample_env['HTTP_X_B3_SAMPLED'] = id.sampled
        end
              
        it "sets existing trace variable HTTP_X_B3_TRACEID in Thread.current" do
          @zipkin_tracer.call(@sample_env)
          Thread.current['HTTP_X_B3_TRACEID'].should == @sample_env['HTTP_X_B3_TRACEID']
        end
      
        it "sets existing trace variable HTTP_X_B3_SAMPLED in Thread.current" do
          @zipkin_tracer.call(@sample_env)
          Thread.current['HTTP_X_B3_SAMPLED'].should == @sample_env['HTTP_X_B3_SAMPLED']
        end      

        it "incoming HTTP_X_B3_SPANID becomes HTTP_X_B3_PARENTSPANID in Thread.current" do
          @zipkin_tracer.call(@sample_env)
          Thread.current['HTTP_X_B3_PARENTSPANID'].should == @sample_env['HTTP_X_B3_SPANID']
        end
        
        it "HTTP_X_B3_SPANID in Thread.current is set to a new value" do
          @zipkin_tracer.call(@sample_env)
          Thread.current['HTTP_X_B3_SPANID'].should_not == @sample_env['HTTP_X_B3_SPANID']
          Thread.current['HTTP_X_B3_SPANID'].should_not be_nil
        end
      end

      context 'non-existent trace info' do
        (ZipkinTracer::RackHandler::B3_HEADERS - %w(HTTP_X_B3_PARENTSPANID)).each do |header_key|
          it "sets #{header_key} to a non-nil value in Thread.current" do
            @zipkin_tracer.call(@sample_env)
            Thread.current[header_key].should_not be_nil
          end
        end
        
        it "sets HTTP_X_B3_PARENTSPANID to nil" do
          @zipkin_tracer.call(@sample_env)
          Thread.current['HTTP_X_B3_PARENTSPANID'].should be_nil
        end
        
        it "considers trace info missing if HTTP_X_B3_TRACEID is missing but other info. is available" do
          id = Trace::TraceId.new(Trace.generate_id, Trace.generate_id, Trace.generate_id, true, 1)
          @sample_env['HTTP_X_B3_PARENTSPANID'] = id.parent_id
          @sample_env['HTTP_X_B3_SPANID'] = id.span_id
          @sample_env['HTTP_X_B3_SAMPLED'] = id.sampled
          
          @zipkin_tracer.call(@sample_env)
          Thread.current['HTTP_X_B3_PARENTSPANID'].should be_nil # This is equivalent to checking that all trace values were reset.
        end

        it "considers trace info missing if HTTP_X_B3_SPANID is missing but other info. is available" do
          id = Trace::TraceId.new(Trace.generate_id, Trace.generate_id, Trace.generate_id, true, 1)
          @sample_env['HTTP_X_B3_TRACEID'] = id.trace_id
          @sample_env['HTTP_X_B3_PARENTSPANID'] = id.parent_id
          @sample_env['HTTP_X_B3_SAMPLED'] = id.sampled
          
          @zipkin_tracer.call(@sample_env)
          Thread.current['HTTP_X_B3_PARENTSPANID'].should be_nil # This is equivalent to checking that all trace values were reset.
        end

        it "considers trace info missing if HTTP_X_B3_SAMPLED is missing but other info. is available" do
          id = Trace::TraceId.new(Trace.generate_id, Trace.generate_id, Trace.generate_id, true, 1)
          @sample_env['HTTP_X_B3_TRACEID'] = id.trace_id
          @sample_env['HTTP_X_B3_PARENTSPANID'] = id.parent_id
          @sample_env['HTTP_X_B3_SPANID'] = id.span_id
          
          @zipkin_tracer.call(@sample_env)
          Thread.current['HTTP_X_B3_PARENTSPANID'].should be_nil # This is equivalent to checking that all trace values were reset.
        end
        
        it "considers trace info present even if HTTP_X_B3_PARENTSPANID is missing but other info. is available" do
          id = Trace::TraceId.new(Trace.generate_id, Trace.generate_id, Trace.generate_id, true, 1)
          @sample_env['HTTP_X_B3_TRACEID'] = id.trace_id
          @sample_env['HTTP_X_B3_SPANID'] = id.span_id
          @sample_env['HTTP_X_B3_SAMPLED'] = id.sampled
          
          @zipkin_tracer.call(@sample_env)
          Thread.current['HTTP_X_B3_PARENTSPANID'].should == @sample_env['HTTP_X_B3_SPANID']
        end                 
      end
      
      it 'pushes the trace id' do
        ::Trace.should_receive(:push)
        @zipkin_tracer.call(@sample_env)
      end
      
      it 'sets the rpc name' do
        ::Trace.should_receive(:set_rpc_name).with(@sample_env["REQUEST_METHOD"])
        @zipkin_tracer.call(@sample_env)
      end
      
      it 'records the http uri' do
        ::Trace::BinaryAnnotation.should_receive(:new).with("http.uri", @sample_env["PATH_INFO"], "STRING", anything)        
        ::Trace.should_receive(:record)
        @zipkin_tracer.call(@sample_env)
      end
      
      it 'records a SERVER_SEND and SERVER_RECV signal' do
        ::Trace::Annotation.should_receive(:new).with(::Trace::Annotation::SERVER_SEND, anything)
        ::Trace::Annotation.should_receive(:new).with(::Trace::Annotation::SERVER_RECV, anything)
        ::Trace.should_receive(:record)
        @zipkin_tracer.call(@sample_env)
      end
      
      it 'calls the app' do
        @mocked_app.should_receive(:call).with(@sample_env)
        @zipkin_tracer.call(@sample_env)
      end

      it 'calls the app even when the tracer raises while the call method is called' do
        ::Trace.stub('push').and_raise(RuntimeError)
        @mocked_app.should_receive(:call).with(@sample_env)
        @zipkin_tracer.call(@sample_env)
      end

      it 'returns even when the tracer raises' do
        ::Trace.stub('pop').and_raise(RuntimeError)
        @zipkin_tracer.call(@sample_env)
      end
      
      it 'pops the trace' do
        ::Trace.should_receive(:pop)
        @zipkin_tracer.call(@sample_env)
      end
    end
    
    it "samples probabalistically" do
      @sample_zipkin_tracer_config[:sample_rate] = 0.1
      num_requests = 100
      expected_samples = num_requests * @sample_zipkin_tracer_config[:sample_rate]
      zipkin_tracer = ZipkinTracer::RackHandler.new(@mocked_app, @sample_zipkin_tracer_config)
      sample_count = 0
      num_requests.times do
        zipkin_tracer.call(@sample_env)
        sample_count += 1 if Thread.current['HTTP_X_B3_SAMPLED']
      end
      
      (sample_count > (expected_samples - 10) && sample_count < expected_samples + 10).should be_true
    end
      
  end
    
end
