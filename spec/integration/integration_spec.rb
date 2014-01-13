require 'spec_helper'
require 'json'
require 'support/test_app'

describe 'integrations' do
  before(:all) do
    @port1 = 4444
    @base_url1 = "http://localhost:#{@port1}"
    ru_location = File.join(`pwd`.chomp, 'spec', 'support', 'test_app_config.ru')
    @pipe1 = IO.popen("rackup #{ru_location} -p #{@port1}")

    @port2 = 4445
    @base_url2 = "http://localhost:#{@port2}"
    @pipe2 = IO.popen("rackup #{ru_location} -p #{@port2}")
    
    sleep(2)
  end
  
  after(:each) do
    TestApp.clear_traces
  end
  
  after(:all) do
    Process.kill("KILL", @pipe1.pid)
    Process.kill("KILL", @pipe2.pid)
  end
  
  it 'has correct trace information on initial call to instrumented service' do
    response_str = `curl #{@base_url1}/hello_world`
    
    response_str.should == 'Hello World'
    traces = TestApp.read_traces
    traces.size.should == 1
    assert_level_0_trace_correct(traces)
  end  
  
  it 'has correct trace information when the instrumented service calls itself, passing on trace information' do
    response_str = `curl #{@base_url1}/ouroboros?out_port=#{@port2}`

    response_str.should == 'Ouroboros says Hello World'
    traces = TestApp.read_traces
    traces.size.should == 2
    assert_level_0_trace_correct(traces)
    assert_level_1_trace_correct(traces)
  end
  
  # Assert that the first level of trace data is correct (or not!).
  # The trace_id and span_id should not be empty.  The parent_span_id should
  # be empty, as a 0-level trace has no parent.  The value of 'sampled' should
  # be a boolean.
  def assert_level_0_trace_correct(traces)
    traces[0]['trace_id'].should_not be_empty
    traces[0]['parent_span_id'].should be_empty
    traces[0]['span_id'].should_not be_empty
    [true, false].include?(traces[0]['sampled']).should be_true
  end
  
  # Assert that the second level of trace data is correct (or not!).
  # The trace_id should be that of the 0th level trace_id.  The first level
  # parent_span_id should be identical to the 0th level span_id.  The first
  # level span id should be a new id.
  def assert_level_1_trace_correct(traces)
    traces[1]['trace_id'].should == traces[0]['trace_id']
    traces[1]['parent_span_id'].should == traces[0]['span_id']
    traces[1]['span_id'].should_not be_empty
    [traces[1]['trace_id'], traces[1]['parent_span_id']].include?(traces[1]['span_id']).should be_false
    [true, false].include?(traces[1]['sampled']).should be_true
  end
end
