require 'spec_helper'
require 'json'

describe 'integrations' do
  before(:all) do
    @port = 4444
    @base_url = "http://localhost:#{@port}"
    ru_location = File.join(`pwd`.chomp, 'spec', 'support', 'test_app_config.ru')
    @pipe = IO.popen("rackup #{ru_location} -p #{@port}")
    sleep(2)
  end
    
  after(:all) do
    Process.kill("KILL", @pipe.pid)
  end
  
  it 'has correct trace information on initial call to instrumented service' do
    response_str = `curl #{@base_url}`
    response = JSON.parse(response_str)
    
    response['trace_id'].should_not be_empty
    response['parent_span_id'].should be_empty
    response['span_id'].should_not be_empty
    [true, false].include?(response['sampled']).should be_true
  end  
end
