require 'spec_helper'
require 'zipkin-tracer'

describe ZipkinTracer::FaradayHandler do

  def make_app
    
  end
  
  describe 'call' do
    
    before do
      @sample_app = described_class.new(lambda{|env| env}, *Array({})) 
      @faraday_env = {:request_headers => {}}     
    end
    
    after do
      Thread.current[:HTTP_X_B3_TRACEID] = Thread.current[:HTTP_X_B3_SPANID] = 
      Thread.current[:HTTP_X_B3_PARENTID] = Thread.current[:HTTP_X_B3_SAMPLED] = nil
    end
    
    it 'puts the trace id (as a string) in the request headers if available' do
      Thread.current[:HTTP_X_B3_TRACEID] = 234
      @sample_app.call(@faraday_env).should == 
        {:request_headers=>{"X-B3-Traceid"=>"234", "X-B3-Spanid"=>"", "X-B3-Parentid"=>"", "X-B3-Sampled"=>""}}
    end
    
    it 'puts the span id (as a string) in the request headers if available' do
      Thread.current[:HTTP_X_B3_SPANID] = 333
      @sample_app.call(@faraday_env).should == 
        {:request_headers=>{"X-B3-Traceid"=>"", "X-B3-Spanid"=>"333", "X-B3-Parentid"=>"", "X-B3-Sampled"=>""}}      
    end
    
    it 'puts the parent id (as a string) in the request headers if available' do
      Thread.current[:HTTP_X_B3_PARENTID] = '433'
      @sample_app.call(@faraday_env).should == 
        {:request_headers=>{"X-B3-Traceid"=>"", "X-B3-Spanid"=>"", "X-B3-Parentid"=>"433", "X-B3-Sampled"=>""}}            
    end
    
    it 'puts the sampled value (as a string) in the request header if available' do
      Thread.current[:HTTP_X_B3_SAMPLED] = true
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
