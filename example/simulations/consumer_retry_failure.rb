# case for scheduler retry that failed and eventually went into dead letter.
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
  config.max_retry = ENV['MAX_RETRY']
  config.maxlen = ENV['MAXLEN']
  config.connection_pool_size = ENV['CONNECTION_POOL_SIZE']
  config.connection_timeout = ENV['CONNECTION_TIMEOUT']
end

require_relative '../models/order'

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_io_medium_failure_retry', task_type: :io_bound_medium, is_retry: true, group: 'group-7', consumer: 'consumer-7') do |data|
  payload = data['payload'] # nil
  order = Order.new(order_id: payload["order_id"], total_payment: payload['total_payment']) # error
  order.save
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_retry_failure.rb