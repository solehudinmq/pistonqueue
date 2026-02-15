# frozen_string_literal: true

require_relative '../lib/pistonqueue'

RSpec.describe ::Pistonqueue::Producer do
  describe "#redis_stream" do
    let(:redis) { Redis.new(url: "redis://127.0.0.1:6379/15") }
    let(:topic) { "events_stream" }
    let(:producer) { described_class.new(driver: :redis_stream) }

    before do
      ::Pistonqueue.configure do |config|
        config.redis_url = "redis://127.0.0.1:6379/15"
      end
    end

    it "successfully sent data to redis stream" do
      request_body = { order_id: "ORD-1", total_payment: 10000 }
      
      result = producer.perform(topic: topic, data: request_body)

      expect(result).to match(/\d+-\d+/)

      results = redis.xrange(topic, "-", "+")
      expect(results.first[1]).to eq({ "payload" => request_body.to_json })
    end

    it "failed to send data to redis stream" do
      request_body = "failed"

      expect { producer.perform(topic: topic, data: request_body) }.to raise_error(ArgumentError, "The 'data' parameter value must contain an object.")
    end
  end
end
