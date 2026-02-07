# case for consumer by displaying data with log.
require 'pistonqueue'

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_io_light', task_type: :io_bound_light, group: 'group-1', consumer: 'consumer-1') do |data|
  puts data
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_1.rb