require 'spec_helper'
require 'zipkin-tracer'

describe ZipkinTracer::FaradayHandler do
  
  describe 'call' do
    
    before do
      @sample_app = described_class.new(lambda{|env| env}, *Array({})) 
      @faraday_env = {:request_headers => {}}     
    end
    
    after do
      ZipkinTracer::IntraProcessTraceId.current = nil
    end
    
    it 'puts the trace id (as a string) in the request headers if available' do
      ZipkinTracer::IntraProcessTraceId.current = mock(
        :trace_id => '234',
        :span_id => '',
        :parent_id => '',
        :sampled => ''
      )
      @sample_app.call(@faraday_env).should == 
        {:request_headers=>{"X-B3-Traceid"=>"234", "X-B3-Spanid"=>"", "X-B3-Parentid"=>"", "X-B3-Sampled"=>""}}
    end
    
    it 'puts the span id (as a string) in the request headers if available' do
      ZipkinTracer::IntraProcessTraceId.current = mock(
        :trace_id => '',
        :span_id => '333',
        :parent_id => '',
        :sampled => ''
      )      
      @sample_app.call(@faraday_env).should == 
        {:request_headers=>{"X-B3-Traceid"=>"", "X-B3-Spanid"=>"333", "X-B3-Parentid"=>"", "X-B3-Sampled"=>""}}      
    end
    
    it 'puts the parent id (as a string) in the request headers if available' do
      ZipkinTracer::IntraProcessTraceId.current = mock(
        :trace_id => '',
        :span_id => '',
        :parent_id => '433',
        :sampled => ''
      )      
      @sample_app.call(@faraday_env).should == 
        {:request_headers=>{"X-B3-Traceid"=>"", "X-B3-Spanid"=>"", "X-B3-Parentid"=>"433", "X-B3-Sampled"=>""}}            
    end
    
    it 'puts the sampled value (as a string) in the request header if available' do
      ZipkinTracer::IntraProcessTraceId.current = mock(
        :trace_id => '',
        :span_id => '',
        :parent_id => '',
        :sampled => true
      )            
      @sample_app.call(@faraday_env).should == 
        {:request_headers=>{"X-B3-Traceid"=>"", "X-B3-Spanid"=>"", "X-B3-Parentid"=>"", "X-B3-Sampled"=>"true"}}      
    end
    
    it 'continues to work if call code raises' do
      Thread.stub(:current).and_raise(ArgumentError.new)
      @sample_app.call(@faraday_env)
      Thread.unstub(:current)
    end  
  end
    
end
