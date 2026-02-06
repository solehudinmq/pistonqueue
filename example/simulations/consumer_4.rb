require 'pistonqueue'

def fibonacci(n)
  return n if n <= 1
  fibonacci(n - 1) + fibonacci(n - 2)
end

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_cpu', task_type: :cpu_bound, group: 'group-4', consumer: 'consumer-4') do |data|
  rand_number = rand(2..40)
  result = fibonacci(rand_number)
  puts "Result : #{result}"
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_4.rb