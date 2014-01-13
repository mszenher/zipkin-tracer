# A simple class used for testing purposes in which we log messages (at all standard log
# levels) in memory.
#
class InMemoryLogger
  LOG_LEVELS = %w(debug info warn error fatal unknown)
  class << self
    def logs_at(level)
      raise(ArgumentError, "log_level must be in #{LOG_LEVELS.to_s}") unless LOG_LEVELS.include?(level)
      eval("@#{level}")
    end
    
    LOG_LEVELS.each do |log_level|
      define_method(log_level) { |msg|
        eval("@#{log_level} ||= []")
        eval("@#{log_level} << msg")
      }
    end
  end  
end
