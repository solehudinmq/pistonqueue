# case for consumer by storing data in database.
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

require_relative '../models/order'

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_io_medium', task_type: :io_bound_medium, group: 'group-2', consumer: 'consumer-2') do |data|
  order = Order.new(order_id: data["order_id"], total_payment: data['total_payment'])
  order.save
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_2.rb