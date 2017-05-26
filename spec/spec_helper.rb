require "bundler/setup"
require "event_sourcery/postgres"
require 'event_sourcery/rspec/event_store_shared_examples'
require 'timeout'

Dir.glob(File.dirname(__FILE__) + '/support/**/*.rb') { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
