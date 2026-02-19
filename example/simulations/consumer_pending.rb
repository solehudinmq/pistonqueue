# case for failed consumer and data goes to retry topic.
require 'pistonqueue'

require_relative '../config'
require_relative '../models/order'

recovery = ::Pistonqueue::RecoveryConsumer.new(driver: :redis_stream)
recovery.perform(topic: 'topic_io_medium', task_type: :io_bound_medium, group: 'group-11', consumer: 'consumer-11') do |data|
  order = Order.new(order_id: data["order_id"], total_payment: data['total_payment']) 
  order.save
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_pending.rb