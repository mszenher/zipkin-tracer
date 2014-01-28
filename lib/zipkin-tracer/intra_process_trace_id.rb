# This class encapsulates storage of the trace_id in the Ruby Thread variable so it is available
# to the process consuming this gem (and is available to the faraday middleware).
#
module ZipkinTracer
  class IntraProcessTraceId
    
    # Store the current trace id so it is available intra-process.
    def self.current=(current_id)
      Thread.current['TRACEID'] = current_id      
    end
    
    # Get the current trace id so it is available intra-process.
    def self.current
      Thread.current['TRACEID']
    end
  end
end
