# the retry case fails completely and the data is saved to the dead letter table.
require 'pistonqueue'

require_relative '../config'
require_relative '../models/dead_letter'

dead_letter = ::Pistonqueue::DlqConsumer.new(driver: :redis_stream)
dead_letter.perform(topic: 'topic_io_medium_failure', task_type: :io_bound_medium, group: 'group-8', consumer: 'consumer-8') do |original_id, original_data, error, failed_at|
  dead_letter = DeadLetter.new(original_id: original_id, original_data: original_data, error: error, failed_at: failed_at)
  dead_letter.save
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_dead_letter.rb