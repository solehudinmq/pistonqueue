# order.rb

require 'sinatra'
require 'active_record'

# database connection configuration.
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: File.expand_path('../db/development.sqlite3', __dir__)
)

# model
class Order < ActiveRecord::Base
end

# migration to create orders table.
ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.table_exists?(:orders)
    create_table :orders do |t|
      t.string :order_id
      t.integer :total_payment
      t.timestamps
    end
  end
end