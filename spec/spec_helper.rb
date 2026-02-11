# frozen_string_literal: true

require 'redis'
require 'json'
require 'byebug'
require 'async'

require_relative '../example/models/order'
require_relative '../example/models/dead_letter'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    Redis.new(url: "redis://127.0.0.1:6379/15").flushdb
    Order.delete_all
    DeadLetter.delete_all
  end
end
