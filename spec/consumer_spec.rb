# frozen_string_literal: true

require_relative '../lib/pistonqueue'

RSpec.describe ::Pistonqueue::Consumer do
  describe "#redis_stream" do
    let(:redis) { Redis.new(url: "redis://127.0.0.1:6379/15") }
    let(:topic) { "events_stream" }
    let(:consumer) { ::Pistonqueue::Consumer.new(driver: :redis_stream) }
  end
end