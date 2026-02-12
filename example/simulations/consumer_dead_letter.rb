# the retry case fails completely and the data is saved to the dead letter table.
require 'pistonqueue'

require_relative '../config'
require_relative '../models/dead_letter'

dead_letter = ::Pistonqueue::DeadLetter.new(driver: :redis_stream)
dead_letter.subscribe(topic: 'topic_io_medium_failure_dlq', task_type: :io_bound_medium, group: 'group-7', consumer: 'consumer-7') do |data|
  dead_letter = DeadLetter.new(original_id: data["original_id"], original_data: data['original_data'], error: data['error'], failed_at: data['failed_at'])
  dead_letter.save
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_dead_letter.rb