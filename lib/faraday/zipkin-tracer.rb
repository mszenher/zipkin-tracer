module ZipkinTracer
  class FaradayHandler
    def initialize(next_middleware)
      @next_middleware = next_middleware
    end
    
    def call(env)
      # do something with the request
      Thread.current.keys.each do |thread_key|
        if thread_key.to_s.start_with?('HTTP_X_B3')
          env[:request_headers][thread_key.to_s.gsub('HTTP_', '')] = Thread.current[thread_key].to_s
        end
      end
      @next_middleware.call(env)
    end
  end
end