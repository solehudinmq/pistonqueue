require 'pistonqueue'

require_relative 'order'

class ConsumerService
    def self.run
        Pistonqueue::Consumer.run do |data|
            puts "Data from redis queue : #{data}"
            order = Order.new(user_id: data["user_id"], order_date: Date.today, total_amount: data["total_amount"])
            order.save
        end
    end
end

ConsumerService.run