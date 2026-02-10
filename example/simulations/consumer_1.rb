# case for consumer by displaying data with log.
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
  config.max_local_retry = ENV['MAX_LOCAL_RETRY']
end

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_io_light', task_type: :io_bound_light, group: 'group-1', consumer: 'consumer-1') do |data|
  puts data
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_1.rb