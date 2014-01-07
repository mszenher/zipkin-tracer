require 'zipkin-tracer'
require 'json'

# This handy little app consumes both the rack and faraday zipkin middlewares.  We'll use 
# this app to do some light integration testing on these middlewares.
#
class TestApp
  # All calls will simply return the current state of the Zipkin trace variables, which is exactly what
  # we want to test!
  def call env
    response_body = {
      'trace_id'        => Thread.current['HTTP_X_B3_TRACEID'].to_s,
      'parent_span_id'  => Thread.current['HTTP_X_B3_PARENTSPANID'].to_s,
      'span_id'         => Thread.current['HTTP_X_B3_SPANID'].to_s,
      'sampled'         => Thread.current['HTTP_X_B3_SAMPLED']
    }
    
    [ 200, {"Content-Type" => "application/json"}, [response_body.to_json] ] 
  end
end

zipkin_tracer_config = {
  service_name: 'your service name here', 
  service_port: 9410, 
  sample_rate: 1, 
  scribe_server: '127.0.0.1:9410'
}

use ZipkinTracer::RackHandler, zipkin_tracer_config
run TestApp.new