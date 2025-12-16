require 'redis'
require 'concurrent'
require 'connection_pool'
require 'json'

# This code is a copy of lib/pistonqueue.rb but customized so that it can be tested in rspec.
module PistonqueueTest
  class Error < StandardError; end
  # Your code goes here...

  PISTON_QUEUE='PISTON_QUEUE'.freeze
  REDIS_URL='redis://localhost:6380'.freeze # redis-server --port 6380
  CONNECTION_TIMEOUT=5.freeze
  TOTAL_CPU_CORE=Concurrent.physical_processor_count.freeze
  TOTAL_THREAD_PRODUCER = ( (TOTAL_CPU_CORE * 2) + 1 ).freeze
  TOTAL_THREAD_CONSUMER = ( ((TOTAL_CPU_CORE * 2) + 1) / TOTAL_CPU_CORE ).freeze

  class Producer
    def self.add_to_queue(request_data)
      begin
          raise 'Request data must be in hash.' unless request_data.is_a?(Hash)

          # create a redis connection pool.
          @redis_pool ||= ConnectionPool.new(size: TOTAL_THREAD_PRODUCER, timeout: CONNECTION_TIMEOUT) do
            Redis.new(url: REDIS_URL)
          end
          
          # save requests to queue in redis.
          @redis_pool.with do |redis_conn|
              redis_conn.lpush(PISTON_QUEUE, request_data.to_json)
          end

          true
      rescue => e
          false
      end
    end
  end

  class Consumer
    def self.run(&service_block)
      worker_pids = []
      
      TOTAL_CPU_CORE.times do |cpu_number|
        pid = fork do
          pool_size = TOTAL_THREAD_CONSUMER + 2

          redis_pool = ConnectionPool.new(size: pool_size, timeout: CONNECTION_TIMEOUT) do
            Redis.new(url: REDIS_URL)
          end

          thread_pool = Concurrent::FixedThreadPool.new(
            pool_size, 
            max_queue: 1000
          )

          queue_data = redis_pool.with do |redis_conn|
            redis_conn.brpop(PISTON_QUEUE, timeout: CONNECTION_TIMEOUT)
          end
          
          if queue_data
            data = JSON.parse(queue_data[1])
            latch = Concurrent::CountDownLatch.new(1)

            thread_pool.post do
              begin
                # Penggunaan Thread.current.object_id membantu debugging thread
                puts "[PID: #{Process.pid} | T_ID: #{Thread.current.object_id}] Processing data..."
                
                # Panggil service melalui block yang disimpan
                service_block.call(data) if service_block
              rescue => e
                # Pastikan Anda punya mekanisme retry/dead-letter queue di sini
                puts "[ERROR in Worker Thread] PID #{Process.pid}: #{e.message}"
              ensure
                latch.count_down
              end
            end

            latch.wait
          end

          thread_pool.shutdown
          thread_pool.wait_for_termination(10)
        end

        worker_pids << pid
      end
    
      Process.waitall
    rescue Interrupt
      worker_pids.each do |pid|
        begin
          Process.kill('TERM', pid)
        rescue Errno::ESRCH
        end
      end
      Process.waitall
    end
  end
end