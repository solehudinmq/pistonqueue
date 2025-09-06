# frozen_string_literal: true

require_relative './pistonqueue_test' # code duplicate from 'lib/pistonqueue.rb', specifically for testing

require 'byebug'
require_relative '../example/test/order'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
