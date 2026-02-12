# case for scheduler retry that failed and eventually went into dead letter.
require 'pistonqueue'

require_relative '../config'
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