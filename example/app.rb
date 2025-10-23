# app.rb
require 'sinatra'
require 'json'
require 'byebug'
require 'pistonqueue'

require_relative 'order'

before do
  content_type :json
end

# Rute untuk menerima request dari aplikasi 3rdparty
post '/sync' do
  begin
    request_body = JSON.parse(request.body.read)

    # save request data to redis queue
    Pistonqueue::Producer.add_to_queue(request_body)

    { data: true }.to_json
  rescue => e
    status 500
    return { error: e.message }.to_json
  end
end

# get data orders
get '/orders' do
  begin
    orders = Order.all

    { count: orders.size, orders: orders }.to_json
  rescue => e
    status 500
    return { error: e.message }.to_json
  end
end

# note : make sure consumer.rb is running in the background (using systemd) before running app.rb

# ====== run producer ======
# 1. open terminal
# 2. cd your_project
# 3. bundle install
# 4. bundle exec ruby app.rb
# 5. create data order
# curl --location 'http://localhost:4567/sync' \
# --header 'Content-Type: application/json' \
# --data '{
#     "user_id": 1,
#     "total_amount": 30000
# }'
# 6. get data order
# curl --location 'http://localhost:4567/orders'

# How to check data in the queue :
# redis-cli
# LRANGE PISTON_QUEUE 0 -1