# dead_letter.rb

require 'sinatra'
require 'active_record'

# database connection configuration.
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: File.expand_path('../db/development.sqlite3', __dir__)
)

# model
class DeadLetter < ActiveRecord::Base
end

# migration to create dead_letters table.
ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.table_exists?(:dead_letters)
    create_table :dead_letters do |t|
      t.string :original_id
      t.text :original_data
      t.string :error
      t.string :failed_at
      t.timestamps
    end
  end
end