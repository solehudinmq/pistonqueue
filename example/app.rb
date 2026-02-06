# app.rb
require 'sinatra'
require 'json'
require 'byebug'
require 'pistonqueue'

require_relative 'models/order'

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
