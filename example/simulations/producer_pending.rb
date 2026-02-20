require 'async'
require 'async/semaphore'
require 'async/barrier'
require 'redis'
require 'connection_pool'
require 'pistonqueue'

puts "🚀 Starting Pending Producer Simulation..."

topic = ARGV[0]
total_loop = ARGV[1]
group_number = ARGV[2]

if topic && total_loop && group_number
  start_time = Time.now
  n_loop = total_loop.to_i
  
  group = "group-#{group_number}"
  consumer = "consumer-#{group_number}"

  is_dead_letter = false
  if topic.include?('dlq')
    is_dead_letter = true
  end

  Async do |task|
    redis_pool = ConnectionPool.new(size: 10, timeout: 2000) do
      Redis.new(url: 'redis://127.0.0.1:6379')
    end

    barrier = Async::Barrier.new
    semaphore = Async::Semaphore.new(100, parent: barrier)

    # 1. Pastikan Group Ada
    begin
      redis_pool.with { |conn| conn.xgroup(:create, topic, group, '$', mkstream: true) }
    rescue Redis::CommandError => e
      puts "ℹ️ Group already exists or stream ready."
    end

    # 2. Consumer Task (Dibuat Loop sampai n_loop tercapai)
    consumer_task = task.async do
      processed_count = 0
      puts "📥 Consumer started, waiting for data..."
      
      while processed_count < n_loop
        result = redis_pool.with do |conn|
          # Membaca data baru ('>')
          conn.xreadgroup(group, consumer, topic, '>', count: 50, block: 2000)
        end

        if result && result[topic]
          batch_size = result[topic].size
          processed_count += batch_size
          puts "📦 Read #{batch_size} messages (Total Pending: #{processed_count}/#{n_loop})"
          
          # CATATAN: Kita TIDAK memanggil XACK di sini.
          # Pesan otomatis masuk XPENDING setelah XREADGROUP berhasil.
        end
        
        # Break jika sudah mencapai target agar tidak kena block timeout di akhir
        break if processed_count >= n_loop
      end
      puts "🏁 Consumer finished reading all #{n_loop} messages."
    end

    # 3. Producer Task
    producer = ::Pistonqueue::Producer.new(driver: :redis_stream)

    n_loop.times do |i|
      semaphore.async do
        request_body = { order_id: "ORD-#{i}", total_payment: rand(10000..500000) }

        payload = if is_dead_letter
          {
            original_id: "#{i}",
            original_data: request_body.to_json,
            error: 'Error dead letter',
            failed_at: Time.now.to_s
          }
        else
          request_body
        end

        producer.perform(topic: topic, data: payload)
      end
    end

    # Tunggu producer selesai kirim dan consumer selesai baca
    barrier.wait 
    consumer_task.wait
  end

  duration = Time.now - start_time
  puts "\n✅ #{n_loop} process completed in #{duration.round(2)} seconds."
  puts "Throughput: #{(n_loop / duration).round(2)} req/sec"
  puts "💡 Check pending status with: redis-cli XPENDING #{topic} #{group}"
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
# - bundle exec ruby producer_pending.rb <topic-name> <total-data> <group-number>
#   a. parameter description :     
#     1. topic-name : name of the topic to which data will be sent, for example : topic_io_light / topic_io_medium / topic_io_heavy / topic_cpu.
#     2. total-data : amount of looping data, for example : 5000.
#     3. group-number : number of group, for example : 12.
#   b. how to use : 
#     1. bundle exec ruby producer_pending.rb topic_io_medium 5000 12