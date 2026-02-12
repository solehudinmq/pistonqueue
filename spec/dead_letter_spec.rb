# frozen_string_literal: true

require_relative '../lib/pistonqueue'
require 'securerandom'

RSpec.describe ::Pistonqueue::DeadLetter, type: :reactor do
  describe "#redis_stream" do
    let(:redis) { Redis.new(url: "redis://127.0.0.1:6379/15") }
    let(:topic) { "events_stream" }
    let(:group_name) { "group-1" }
    let(:consumer_name) { "consumer-1" }
    let(:producer) { ::Pistonqueue::Producer.new(driver: :redis_stream) }
    let(:consumer) { ::Pistonqueue::Consumer.new(driver: :redis_stream) }
    let(:dead_letter) { described_class.new(driver: :redis_stream) }

    before do
      ::Pistonqueue.configure do |config|
        config.redis_url = "redis://127.0.0.1:6379/15"
      end
    end

    it "successfully received data from redis stream, and there was no problem processing consumer dead letter" do
      order_id = "ORD-#{SecureRandom.uuid}"
      total_payment = rand(10000..99999)

      Async do |task|
        # the main consumer process failed, and data was sent to <your-topic>_retry. [FAILED]
        consumer_task = task.async do
          consumer.subscribe(topic: topic, task_type: :io_bound_light, group: group_name, consumer: consumer_name, is_stop: true) do |data|
            raise "The main consumer process failed."
          end
        end

        # the consumer process tries again outside the main consumer to process the previously failed data, but still fails. The data is then sent to <your-topic>_dlq. [FAILED]
        consumer_task2 = task.async do
          consumer.subscribe(topic: "#{topic}_retry", task_type: :io_bound_light, is_retry: true, group: group_name, consumer: consumer_name, is_stop: true) do |data|
            raise "The retry consumer process failed."
          end
        end

        # the consumer process for receiving "dead letter" data (data that failed to be retried outside the main consumer). [SUCCESS]
        dead_letter_task = task.async do
          dead_letter.subscribe(topic: "#{topic}_dlq", task_type: :io_bound_light, group: group_name, consumer: consumer_name, is_stop: true) do |data|
            original_data = data[:original_data]
            expect(original_data["order_id"]).to eq(order_id)
            expect(original_data["total_payment"]).to eq(total_payment)
            expect(data[:error]).to eq("The retry consumer process failed.")
          end
        end

        task.sleep(0.1)

        request_body = { order_id: order_id, total_payment: total_payment }
        
        producer.publish(topic: topic, data: request_body)

        consumer_task.wait
        consumer_task2.wait
        dead_letter_task.wait
      end
    end

    it 'successfully received data from redis stream, but there was a problem processing consumer dead letter' do
      order_id = "ORD-#{SecureRandom.uuid}"
      total_payment = rand(10000..99999)

      Async do |task|
        # the main consumer process failed, and data was sent to <your-topic>_retry. [FAILED]
        consumer_task = task.async do
          consumer.subscribe(topic: topic, task_type: :io_bound_light, group: group_name, consumer: consumer_name, is_stop: true) do |data|
            raise "The main consumer process failed."
          end
        end

        # the consumer process tries again outside the main consumer to process the previously failed data, but still fails. The data is then sent to <your-topic>_dlq. [FAILED]
        consumer_task2 = task.async do
          consumer.subscribe(topic: "#{topic}_retry", task_type: :io_bound_light, is_retry: true, group: group_name, consumer: consumer_name, is_stop: true) do |data|
            raise "The retry consumer process failed."
          end
        end

        # the consumer process to receive dead letter data, but failed during the process. [FAILED]
        dead_letter_task = task.async do
          dead_letter.subscribe(topic: "#{topic}_dlq", task_type: :io_bound_light, group: group_name, consumer: consumer_name, is_stop: true) do |data|
            raise "The dead letter consumer process failed."
          end
        end

        # the consumer process to receive dead letter archive data, please manually check the error that occurred. [SUCCESS]
        dead_letter_task2 = task.async do
          dead_letter.subscribe(topic: "#{topic}_dlq_archive", task_type: :io_bound_light, group: group_name, consumer: consumer_name, is_stop: true) do |data|
            original_data = data[:original_data]
            expect(original_data["order_id"]).to eq(order_id)
            expect(original_data["total_payment"]).to eq(total_payment)
            expect(data[:error]).to eq("The dead letter consumer process failed.")
          end
        end

        task.sleep(0.1)

        request_body = { order_id: order_id, total_payment: total_payment }
        
        producer.publish(topic: topic, data: request_body)

        consumer_task.wait
        consumer_task2.wait
        dead_letter_task.wait
        dead_letter_task2.wait
      end
    end

    it 'successfully received data from redis stream, but failed to process because the group does not exist' do
      order_id = "ORD-#{SecureRandom.uuid}"
      total_payment = rand(10000..99999)

      Async do |task|
        dead_letter_task = task.async do
          dead_letter.subscribe(topic: topic, task_type: :io_bound_light, group: group_name, is_stop: true) do |data| end
        rescue ArgumentError => e
          expect(e.message).to eq("Key parameter with 'group' or 'consumer' name is mandatory.")
        end

        task.sleep(0.1)

        request_body = { order_id: order_id, total_payment: total_payment }
        
        producer.publish(topic: topic, data: request_body)

        dead_letter_task.wait
      end
    end

    it 'successfully received data from redis stream, but failed to process because the consumer does not exist' do
      order_id = "ORD-#{SecureRandom.uuid}"
      total_payment = rand(10000..99999)

      Async do |task|
        dead_letter_task = task.async do
          dead_letter.subscribe(topic: topic, task_type: :io_bound_light, group: group_name, is_stop: true) do |data| end
        rescue ArgumentError => e
          expect(e.message).to eq("Key parameter with 'group' or 'consumer' name is mandatory.")
        end

        task.sleep(0.1)

        request_body = { order_id: order_id, total_payment: total_payment }
        
        producer.publish(topic: topic, data: request_body)

        dead_letter_task.wait
      end
    end
  end
end