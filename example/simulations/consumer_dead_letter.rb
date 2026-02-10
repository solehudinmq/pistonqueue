# the retry case fails completely and the data is saved to the dead letter table.
require 'pistonqueue'
require 'dotenv'

Dotenv.load('../.env')

Pistonqueue.configure do |config|
  config.io_light_fiber = ENV['IO_LIGHT_FIBER']
  config.io_medium_fiber = ENV['IO_MEDIUM_FIBER']
  config.io_heavy_fiber = ENV['IO_HEAVY_FIBER']
  config.cpu_fiber = ENV['CPU_FIBER']
  config.redis_url = ENV['REDIS_URL']
  config.redis_block_duration = ENV['REDIS_BLOCK_DURATION']
  config.redis_batch_size = ENV['REDIS_BATCH_SIZE']
  config.max_retry = ENV['MAX_RETRY']
  config.max_local_retry = ENV['MAX_LOCAL_RETRY']
end

require_relative '../models/dead_letter'

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_io_medium_failure_dlq', task_type: :io_bound_medium, group: 'group-7', consumer: 'consumer-7') do |data|
  dead_letter = DeadLetter.new(original_id: data["original_id"], original_data: data['original_data'], error: data['error'], failed_at: data['failed_at'])
  dead_letter.save
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_dead_letter.rb