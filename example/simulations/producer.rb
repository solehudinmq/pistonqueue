require 'async'
require 'async/http/internet'
require 'async/semaphore'
require 'async/barrier'

puts "🚀 Starting Producer Simulation..."

Async do |task|
  internet = Async::HTTP::Internet.new
  url = "http://localhost:4567/publish"
  topic = ARGV[0]
  headers = [['content-type', 'application/json'], ['x_topic', topic]]
  
  semaphore = Async::Semaphore.new(100)
  barrier = Async::Barrier.new
  
  start_time = Time.now

  5000.times do |i|
    barrier.async(parent: semaphore) do
      begin
        payload = { order_id: "ORD-#{i}", total_payment: rand(10000..500000) }.to_json
        
        response = internet.post(url, headers, payload)
        response.finish
      rescue => e
        puts "Request #{i} failed: #{e.message}"
      ensure
        response&.close
      end
    end
  end

  barrier.wait 

  duration = Time.now - start_time
  puts "\n✅ 5000 process completed in #{duration.round(2)} seconds."
  puts "Throughput: #{(5000 / duration).round(2)} req/sec"
ensure
  internet&.close
end

# make sure to run this command first :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby app.rb

# then run this command :
# - open a new tab
# - cd example/simulations
# - bundle install
# - bundle exec ruby producer.rb topic_io_medium
#   topic choices : topic_io_light / topic_io_medium / topic_io_heavy / topic_cpu