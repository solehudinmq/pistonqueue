# frozen_string_literal: true

require_relative '../lib/pistonqueue'
require 'securerandom'

RSpec.describe ::Pistonqueue::Consumer, type: :reactor do
  describe "#redis_stream" do
    let(:redis) { Redis.new(url: "redis://127.0.0.1:6379/15") }
    let(:topic) { "events_stream" }
    let(:group_name) { "group-1" }
    let(:consumer_name) { "consumer-1" }
    let(:producer) { ::Pistonqueue::Producer.new(driver: :redis_stream) }
    let(:consumer) { described_class.new(driver: :redis_stream) }

    before do
      ::Pistonqueue.configure do |config|
        config.redis_url = "redis://127.0.0.1:6379/15"
      end
    end

    it 'successfully received data from redis stream and processed business logic in the main consumer' do
      order_id = "ORD-#{SecureRandom.uuid}"
      total_payment = rand(10000..99999)

      Async do |task|
        consumer_task = task.async do
          consumer.subscribe(topic: topic, task_type: :io_bound_light, group: group_name, consumer: consumer_name, is_stop: true) do |data|
            expect(data["order_id"]).to eq(order_id)
            expect(data["total_payment"]).to eq(total_payment)
          end
        end

        task.sleep(0.1)

        request_body = { order_id: order_id, total_payment: total_payment }
        
        producer.publish(topic: topic, data: request_body)

        consumer_task.wait
      end
    end

    it 'successfully received data from redis stream and successfully processed business logic via retry consumer outside the main consumer' do
      order_id = "ORD-#{SecureRandom.uuid}"
      total_payment = rand(10000..99999)

      Async do |task|
        # the main consumer process failed, and data was sent to <your-topic>_retry. [FAILED]
        consumer_task = task.async do
          consumer.subscribe(topic: topic, task_type: :io_bound_light, group: group_name, consumer: consumer_name, is_stop: true) do |data|
            raise "The main consumer process failed."
          end
        end

        # The consumer process performs a retry outside the main consumer to process data that previously failed.. [SUCCESS]
        consumer_task2 = task.async do
          consumer.subscribe(topic: topic, task_type: :io_bound_light, is_retry: true, group: group_name, consumer: consumer_name, is_stop: true) do |data|
            expect(data["order_id"]).to eq(order_id)
            expect(data["total_payment"]).to eq(total_payment)
          end
        end

        task.sleep(0.1)

        request_body = { order_id: order_id, total_payment: total_payment }
        
        producer.publish(topic: topic, data: request_body)

        consumer_task.wait
        consumer_task2.wait
      end
    end

    it 'successfully received data from redis stream, but failed to process because the group does not exist' do
      order_id = "ORD-#{SecureRandom.uuid}"
      total_payment = rand(10000..99999)

      Async do |task|
        consumer_task = task.async do
          consumer.subscribe(topic: topic, task_type: :io_bound_light, group: group_name, is_stop: true) do |data| end
        rescue ArgumentError => e
          expect(e.message).to eq("Key parameter with 'group' or 'consumer' name is mandatory.")
        end

        task.sleep(0.1)

        request_body = { order_id: order_id, total_payment: total_payment }
        
        producer.publish(topic: topic, data: request_body)

        consumer_task.wait
      end
    end

    it 'successfully received data from redis stream, but failed to process because the consumer does not exist' do
      order_id = "ORD-#{SecureRandom.uuid}"
      total_payment = rand(10000..99999)

      Async do |task|
        consumer_task = task.async do
          consumer.subscribe(topic: topic, task_type: :io_bound_light, group: group_name, is_stop: true) do |data| end
        rescue ArgumentError => e
          expect(e.message).to eq("Key parameter with 'group' or 'consumer' name is mandatory.")
        end

        task.sleep(0.1)

        request_body = { order_id: order_id, total_payment: total_payment }
        
        producer.publish(topic: topic, data: request_body)

        consumer_task.wait
      end
    end
  end
end