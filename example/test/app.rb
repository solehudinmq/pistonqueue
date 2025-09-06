# app.rb
require 'sinatra'
require 'json'
require 'byebug'
require 'pistonqueue'

# Rute untuk menerima request dari aplikasi 3rdparty
post '/sync' do
    begin
        request_body = JSON.parse(request.body.read)

        # save request data to redis queue
        Pistonqueue::Producer.add_to_queue(request_body)

        content_type :json
        { data: true }.to_json
    rescue => e
        content_type :json
        status 500
        return { error: e.message }.to_json
    end
end

# note : make sure consumer.rb is running in the background (using systemd) before running app.rb

# ====== run producer ======
# open terminal
# cd your_project
# bundle install
# bundle exec ruby app.rb
# curl --location 'http://localhost:4567/sync' \
# --header 'Content-Type: application/json' \
# --data '{
#     "user_id": 1,
#     "total_amount": 30000
# }'

# How to check data in the queue :
# redis-cli
# LRANGE PISTON_QUEUE 0 -1