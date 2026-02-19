# case for failed consumer and data goes to retry topic.
require 'pistonqueue'

require_relative '../config'
require_relative '../models/dead_letter'

recovery = ::Pistonqueue::RecoveryConsumer.new(driver: :redis_stream)
recovery.dead_letter_perform(topic: 'topic_io_medium', task_type: :io_bound_medium, group: 'group-13', consumer: 'consumer-13') do |original_id, original_data, error, failed_at|
  dead_letter = DeadLetter.new(original_id: original_id, original_data: original_data, error: error, failed_at: failed_at)
  dead_letter.save
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_pending_dead_letter.rb