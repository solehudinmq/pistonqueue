# case for consumer with heavy computation in cpu bound.
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

def fibonacci(n)
  return n if n <= 1
  fibonacci(n - 1) + fibonacci(n - 2)
end

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_cpu', task_type: :cpu_bound, group: 'group-4', consumer: 'consumer-4') do |data|
  rand_number = rand(2..40)
  result = fibonacci(rand_number)
  puts "Result : #{result}"
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_4.rb