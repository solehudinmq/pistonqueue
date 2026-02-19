# case for failed consumer and data goes to retry topic.
require 'pistonqueue'

require_relative '../config'
require_relative '../models/order'

recovery = ::Pistonqueue::RecoveryConsumer.new(driver: :redis_stream)
recovery.perform(topic: 'topic_io_medium', task_type: :io_bound_medium, is_retry: true, group: 'group-12', consumer: 'consumer-12') do |data|
  order = Order.new(order_id: data["order_id"], total_payment: data['total_payment']) 
  order.save
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_pending_retry.rb