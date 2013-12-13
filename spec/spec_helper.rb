require 'simplecov'
SimpleCov.start

SPEC_DIR = File.expand_path("..", __FILE__)
lib_dir = File.expand_path("../lib", SPEC_DIR)

$LOAD_PATH.unshift(lib_dir)
$LOAD_PATH.uniq!

require 'rspec'
require 'debugger'

RSpec.configure do |config|
  config.mock_with :rspec
end
