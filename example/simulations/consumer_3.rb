require 'pistonqueue'
require 'async'
require 'async/http/internet'
require 'async/semaphore'

internet = Async::HTTP::Internet.new
semaphore = Async::Semaphore.new(10)
url = "https://jsonplaceholder.typicode.com/todos/1"
headers = [['content-type', 'application/json']]

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_io_heavy', task_type: :io_bound_heavy, group: 'group-3', consumer: 'consumer-3') do |data|  
  semaphore.async do
    begin
      response = internet.get(url, headers)
      puts response.read
    rescue => e
      puts "Request failed : #{e.message}"
    ensure
      response&.close
    end
  end
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_3.rb