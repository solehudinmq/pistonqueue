# app.rb
require 'sinatra'
require 'json'
require 'byebug'
require 'dotenv'
require 'pistonqueue'

Dotenv.load('.env')

require_relative 'models/order'
require_relative 'models/dead_letter'

Pistonqueue.configure do |config|
  config.io_light_fiber = ENV['IO_LIGHT_FIBER']
  config.io_medium_fiber = ENV['IO_MEDIUM_FIBER']
  config.io_heavy_fiber = ENV['IO_HEAVY_FIBER']
  config.cpu_fiber = ENV['CPU_FIBER']
  config.redis_url = ENV['REDIS_URL']
  config.redis_block_duration = ENV['REDIS_BLOCK_DURATION']
  config.redis_batch_size = ENV['REDIS_BATCH_SIZE']
  config.max_local_retry = ENV['MAX_LOCAL_RETRY']
  config.max_retry = ENV['MAX_RETRY']
  config.maxlen = ENV['MAXLEN']
  config.connection_pool_size = ENV['CONNECTION_POOL_SIZE']
  config.connection_timeout = ENV['CONNECTION_TIMEOUT']
end

before do
  content_type :json
end

# route to receive requests from 3rdparty applications.
post '/publish' do
  status 201

  topic = request.env['HTTP_X_TOPIC']
  
  # request body example : { order_id: 'xyz-1', total_payment: 250000 }.
  request_body = JSON.parse(request.body.read)

  # save request data to redis stream
  producer = ::Pistonqueue::Producer.new(driver: :redis_stream)
  result = producer.publish(topic: topic, data: request_body)

  { message_id: result, is_success: result ? true : false }.to_json
end

get '/orders' do
  status 200

  page = (params[:page] || 1).to_i
  per_page = 10
  offset = (page - 1) * per_page

  orders = Order.limit(per_page).offset(offset)

  { current_page: page, total_data: Order.count, data: orders }.to_json
end

get '/dead_letters' do
  status 200

  page = (params[:page] || 1).to_i
  per_page = 10
  offset = (page - 1) * per_page

  dead_letters = DeadLetter.limit(per_page).offset(offset)

  { current_page: page, total_data: DeadLetter.count, data: dead_letters }.to_json
end

error do
  status 500
  { error: env['sinatra.error'].message }.to_json
end

# run this command :
# - open terminal
# - cd example
# - bundle install
# - bundle exec ruby app.rb

# for testing run this command:
# - open a new tab
# - cd example
# - bundle install
#   a. publish data :
    # curl --location 'http://127.0.0.1:4567/publish' \
    # --header 'x_topic: topic_io_light' \
    # --header 'Content-Type: application/json' \
    # --data '{ 
    #     "order_id": "xyz-1", 
    #     "total_payment": 250000 
    # }'
#   b. list orders :
    # curl --location 'http://127.0.0.1:4567/orders?page=1'
#   c. list dead letters : 
    # curl --location 'http://127.0.0.1:4567/dead_letters?page=1'

