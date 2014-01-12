require 'json'

# This handy little app consumes both the rack and faraday zipkin middlewares.  We'll use 
# this app to do some light integration testing on these middlewares.
#
class TestApp
  # All calls will simply return the current state of the Zipkin trace variables, which is exactly what
  # we want to test!
  def call env
    store_current_trace_info
    [ 200, {'Content-Type' => 'application/json'}, ['OK'] ] 
  end
  
  def store_current_trace_info
    current_trace_info = {
      'trace_id'        => Thread.current['HTTP_X_B3_TRACEID'].to_s,
      'parent_span_id'  => Thread.current['HTTP_X_B3_PARENTSPANID'].to_s,
      'span_id'         => Thread.current['HTTP_X_B3_SPANID'].to_s,
      'sampled'         => Thread.current['HTTP_X_B3_SAMPLED']
    }
    self.class.add_trace(current_trace_info.to_json)
  end
  
  # A 'scribe' to store our traces.
  class << self
    def read_traces
      file = File.open('traces.txt', 'r')
      lines = file.readlines.map{ |l| JSON.parse(l) }
      file.close
      lines
    end
    
    def add_trace(trace)
      File.open('traces.txt', 'w') do |f|  
        f.puts trace
      end
    end
    
    def clear_traces
      File.unlink('traces.txt')
    end    
  end
  
end
