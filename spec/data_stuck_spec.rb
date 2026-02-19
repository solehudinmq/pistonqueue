# frozen_string_literal: true

require_relative '../lib/pistonqueue'
require 'securerandom'
require 'ostruct'

RSpec.describe ::Pistonqueue::RecoveryConsumer, type: :reactor do
  describe "#redis_stream" do
    let(:redis) { Redis.new(url: "redis://127.0.0.1:6379/15") }
    let(:topic) { "events_stream" }
    let(:dynamic_topic) { "events_stream" }
    let(:config) { OpenStruct.new(topic: dynamic_topic) }
    let(:group_name) { "group-1" }
    let(:consumer_name) { "consumer-1" }
    let(:order_id) { "ORD-#{SecureRandom.uuid}" }
    let(:total_payment) { rand(10000..99999) }
    let(:producer) { ::Pistonqueue::Producer.new(driver: :redis_stream) }
    let(:recovery) { described_class.new(driver: :redis_stream) }

    before do
      ::Pistonqueue.configure do |config|
        config.redis_url = "redis://127.0.0.1:6379/15"
        config.redis_min_idle_time = 1 # set 1 for testing only.
      end
    end

    before(:each) do
      begin
        redis.xgroup(:create, config.topic, group_name, '$', mkstream: true)
      rescue => e
      end

      Async do |task|
        consumer_task = task.async do
          redis.xreadgroup(group_name, consumer_name, config.topic, '>', count: 10, block: 2000)
        end

        task.sleep(0.1)

        request_body = { order_id: order_id, total_payment: total_payment }

        if config.topic == 'events_stream_dlq' # for the dead letter process.
          producer.perform(topic: config.topic, data: {
            original_id: '1707241234567-0',
            original_data: request_body.to_json,
            error: 'Error dead letter',
            failed_at: '2026-02-19 11:48:24 +0700'
          })
        else # for the main and retry process.
          producer.perform(topic: config.topic, data: request_body)
        end

        consumer_task.wait
      end
    end
    
    context "data stuck during main" do
      it 'pending data is successfully received from redis and performs business logic processing for the main consumer' do
        Async do |task|
          recovery_task = task.async do
            recovery.perform(topic: topic, task_type: :io_bound_light, group: group_name, consumer: consumer_name, is_stop: true) do |data|
              expect(data["order_id"]).to eq(order_id)
              expect(data["total_payment"]).to eq(total_payment)
            end
          end

          recovery_task.wait
        end
      end
    end

    context "data stuck during retry" do
      let(:dynamic_topic) { "events_stream_retry" }

      it 'pending data is successfully received from redis and performs business logic processing for the retry consumer' do
        Async do |task|
          recovery_task = task.async do
            recovery.perform(topic: topic, task_type: :io_bound_light, group: group_name, consumer: consumer_name, is_retry: true, is_stop: true) do |data|
              expect(data["order_id"]).to eq(order_id)
              expect(data["total_payment"]).to eq(total_payment)
            end
          end

          recovery_task.wait
        end
      end
    end

    context "data stuck during dead letter" do
      let(:dynamic_topic) { "events_stream_dlq" }

      it 'pending data is successfully received from redis and performs business logic processing for the dead letter consumer' do
        Async do |task|
          recovery_task = task.async do
            recovery.dead_letter_perform(topic: topic, task_type: :io_bound_light, group: group_name, consumer: consumer_name, is_stop: true) do |original_id, original_data, err_msg, failed_at|
              expect(original_id).to eq('1707241234567-0')
              expect(original_data).to eq({ order_id: order_id, total_payment: total_payment }.to_json)
              expect(err_msg).to eq('Error dead letter')
              expect(failed_at).to eq('2026-02-19 11:48:24 +0700')
            end
          end

          recovery_task.wait
        end
      end
    end
  end
end