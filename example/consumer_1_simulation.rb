require 'pistonqueue'

require_relative 'models/order'

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_io_light', task_type: :io_bound_light, group: 'group-1', consumer: 'consumer-1') do |data|
  # your logic here
  puts data
end