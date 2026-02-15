# frozen_string_literal: true

require_relative '../lib/pistonqueue'
require 'securerandom'

RSpec.describe ::Pistonqueue::RecoveryConsumer, type: :reactor do
  describe "#redis_stream" do
    let(:redis) { Redis.new(url: "redis://127.0.0.1:6379/15") }
    let(:topic) { "events_stream" }
    let(:group_name) { "group-1" }
    let(:consumer_name) { "consumer-1" }
    let(:producer) { ::Pistonqueue::Producer.new(driver: :redis_stream) }
    let(:consumer) { ::Pistonqueue::Consumer.new(driver: :redis_stream) }
    let(:dead_letter) { ::Pistonqueue::DlqConsumer.new(driver: :redis_stream) }
    let(:recovery) { described_class.new(driver: :redis_stream) }

    before do
      ::Pistonqueue.configure do |config|
        config.redis_url = "redis://127.0.0.1:6379/15"
      end
    end
  end
end