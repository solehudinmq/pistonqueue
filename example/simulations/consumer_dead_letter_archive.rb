# retry attempts and dead letter processes failed completely.
require 'pistonqueue'

require_relative '../config'

dead_letter = ::Pistonqueue::DlqConsumer.new(driver: :redis_stream)
dead_letter.perform(topic: 'topic_io_medium_failure', task_type: :io_bound_medium, is_archive: true, group: 'group-10', consumer: 'consumer-10') do |original_id, original_data, error, failed_at|
  dead_letter_archieve_data = { original_id: original_id, original_data: original_data, error: error, failed_at: failed_at }
  puts dead_letter_archieve_data
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_dead_letter_archive.rb