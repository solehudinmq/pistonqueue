# frozen_string_literal: true

RSpec.describe PistonqueueTest do
  before(:all) do
    # Delete old data and enter new data
    Order.delete_all
  end

  it "return success" do
    PistonqueueTest::Producer.add_to_queue({
        "user_id": 1,
        "total_amount": 30000
    })

    PistonqueueTest::Consumer.run do |data|
        order = Order.new(user_id: data["user_id"], order_date: Date.today, total_amount: data["total_amount"])
        order.save
    end
    
    order = Order.first

    expect(order.user_id).to eq(1)
    expect(order.total_amount).to eq(30000)
  end

  it "return error" do
    begin
      PistonqueueTest::Producer.add_to_queue("haha")
    rescue => e
      expect(e.message).to eq("Request data must be in hash.")
    end
  end
end
