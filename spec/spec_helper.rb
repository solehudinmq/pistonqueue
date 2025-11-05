# frozen_string_literal: true

require_relative './pistonqueue_test' # code duplicate from 'lib/pistonqueue.rb', specifically for testing

require 'byebug'
require_relative '../example/order'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    # 'spawn' menjalankan perintah di background dan MENGEMBALIKAN PID
    @redis_pid = spawn("redis-server --port 6380 --daemonize yes", out: '/dev/null', err: '/dev/null')
    sleep 1 # Beri waktu startup
  end

  config.after(:suite) do
    if @redis_pid
      # Mengirim sinyal TERMINATE (TERM) ke proses Redis menggunakan PID
      Process.kill('TERM', @redis_pid)
      
      # Menunggu proses benar-benar mati (optional, tapi disarankan)
      Process.wait(@redis_pid) rescue nil 
    end
  end
end
