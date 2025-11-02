# order.rb
require 'sinatra'
require 'active_record'

# Konfigurasi koneksi database
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/development.sqlite3'
)

# Buat direktori db jika belum ada
Dir.mkdir('db') unless File.directory?('db')

# Model
class Order < ActiveRecord::Base
end

# Migrasi untuk membuat tabel orders
ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.table_exists?(:orders)
    create_table :orders do |t|
        t.integer :user_id
        t.date :order_date
        t.decimal :total_amount
        t.string :status, default: :waiting
        t.timestamps
    end
  end
end