# case for failed consumer and data goes to retry topic.
require 'pistonqueue'

require_relative '../config'
require_relative '../models/order'

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.perform(topic: 'topic_io_medium_failure', task_type: :io_bound_medium, group: 'group-6', consumer: 'consumer-6') do |data|
  payload = data['payload'] # nil
  order = Order.new(order_id: payload["order_id"], total_payment: payload['total_payment']) # error
  order.save
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_failure.rb