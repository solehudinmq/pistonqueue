require 'dotenv'
require 'pistonqueue'
require 'pathname'

root_path = Pathname.new(__dir__)
Dotenv.load(root_path.join('.env'))

::Pistonqueue.configure do |config|
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
  config.redis_min_idle_time = ENV['REDIS_MIN_IDLE_TIME']
end