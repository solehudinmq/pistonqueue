# case for consumer by storing data in database.
require 'pistonqueue'

require_relative '../models/order'

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_io_medium', task_type: :io_bound_medium, group: 'group-2', consumer: 'consumer-2') do |data|
  payload = JSON.parse(data["payload"])

  order = Order.new(order_id: payload["order_id"], total_payment: payload['total_payment'])
  order.save
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_2.rb