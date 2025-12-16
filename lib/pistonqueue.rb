# frozen_string_literal: true

require_relative "pistonqueue/version"

require 'redis'
require 'concurrent'
require 'connection_pool'
require 'json'

module Pistonqueue
  # queue name in Redis to store incoming requests.
  PISTON_QUEUE='PISTON_QUEUE'.freeze
  REDIS_URL=ENV['REDIS_URL'].freeze
  CONNECTION_TIMEOUT=5.freeze
  TOTAL_CPU_CORE=Concurrent.physical_processor_count.freeze
  TOTAL_THREAD_PRODUCER = ( (TOTAL_CPU_CORE * 2) + 1 ).freeze
  TOTAL_THREAD_CONSUMER = ( ((TOTAL_CPU_CORE * 2) + 1) / TOTAL_CPU_CORE ).freeze
  POOL_SIZE = ((ENV['POOL_SIZE'] || 10).to_i + 2).freeze

  # producer is used to store incoming requests from the controller.
  class Producer
    # stores incoming requests in the Redis queue.
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

  # consumer is called in a background job, it is recommended to use systemd.
  class Consumer
    # take requests from the redis queue, and execute them in parallel and concurrently.
    def self.run(&service_block)
      worker_pids = []

      # create child processes according to the number of available CPU cores.
      TOTAL_CPU_CORE.times do |cpu_number|
        pid = fork do
          # create a redis connection pool.
          redis_pool = ConnectionPool.new(size: POOL_SIZE, timeout: CONNECTION_TIMEOUT) do
            Redis.new(url: REDIS_URL)
          end

          # threadpool set
          thread_pool = Concurrent::FixedThreadPool.new(
            TOTAL_THREAD_CONSUMER, 
            max_queue: 1000
          )

          loop do
            # fetch data from redis queue.
            queue_data = redis_pool.with do |redis_conn|
              redis_conn.brpop(PISTON_QUEUE, timeout: CONNECTION_TIMEOUT)
            end
            
            if queue_data
              data = JSON.parse(queue_data[1])

              thread_pool.post do
                begin
                  # Penggunaan Thread.current.object_id membantu debugging thread
                  puts "[PID: #{Process.pid} | T_ID: #{Thread.current.object_id}] Processing data..."
                  
                  # Panggil service melalui block yang disimpan
                  service_block.call(data) if service_block
                rescue => e
                  # Pastikan Anda punya mekanisme retry/dead-letter queue di sini
                  puts "[ERROR in Worker Thread] PID #{Process.pid}: #{e.message}"
                end
              end
            end
          end

          thread_pool.shutdown
          thread_pool.wait_for_termination(10)
        end

        worker_pids << pid
      end
    
      Process.waitall # waiting for all forked child processes to complete
    rescue Interrupt
      # process interrupted. stop all workers...
      worker_pids.each do |pid|
        begin
          Process.kill('TERM', pid)
        rescue Errno::ESRCH
        end
      end
      Process.waitall # waiting for all forked child processes to complete
    end
  end
end
