# case for failed retry in main consumer process.
require 'pistonqueue'

require_relative '../config'
require_relative '../models/order'

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_io_medium_failure_retry', task_type: :io_bound_medium, is_retry: true, group: 'group-5', consumer: 'consumer-5') do |data|
  order = Order.new(order_id: data["order_id"], total_payment: data['total_payment'])
  order.save
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_retry.rb