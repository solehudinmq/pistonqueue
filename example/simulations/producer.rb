require 'async'
require 'async/http/internet'
require 'async/semaphore'
require 'async/barrier'

puts "🚀 Starting Producer Simulation..."

topic = ARGV[0]
total_loop = ARGV[1]

if topic && total_loop
  Async do |task|
    internet = Async::HTTP::Internet.new
    url = "http://localhost:4567/publish"
    
    headers = [['content-type', 'application/json'], ['x_topic', topic]]
    
    semaphore = Async::Semaphore.new(100)
    barrier = Async::Barrier.new
    
    start_time = Time.now

    total_loop.to_i.times do |i|
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
else
  puts "Wrong command, correct example : bundle exec ruby producer.rb topic_io_medium 5000"
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
# - bundle exec ruby producer.rb <topic-name> <total-looping>
#   a. parameter description :     
#     1. topic-name : name of the topic to which data will be sent, for example : topic_io_light / topic_io_medium / topic_io_heavy / topic_cpu.
#     2. total-looping : amount of looping data, for example : 5000.
#   b. how to use : 
#     1. bundle exec ruby producer.rb topic_io_light 10000
#     2. bundle exec ruby producer.rb topic_io_medium 5000
#     3. bundle exec ruby producer.rb topic_io_heavy 1000
#     4. bundle exec ruby producer.rb topic_cpu 100