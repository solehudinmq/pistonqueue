# Pistonqueue

Pistonqueue is a Ruby library for handling backpressure conditions, using queue solutions and leveraging concurrency and parallelism to process each incoming request. This allows our applications to handle high traffic without worrying about overloading our systems.

Pistonqueue utilizes a queue to receive every incoming request and maximizes the execution of each task through concurrency and parallelism. This optimizes system performance when handling requests from third-party applications.

## High Flow

Potential problems if our application is unable to handle backpressure issues :
![Logo Ruby](https://github.com/solehudinmq/pistonqueue/blob/development/high_flow/Pistonqueue-problem.jpg)

With Pistonqueue, our application is now able to handle as many requests as possible :
![Logo Ruby](https://github.com/solehudinmq/pistonqueue/blob/development/high_flow/Pistonqueue-solution.jpg)

## Installation

The minimum version of Ruby that must be installed is 3.0.
Need to install redis to implement queue.

Add this line to your application's Gemfile :

```ruby
gem 'pistonqueue', git: 'git@github.com:solehudinmq/pistonqueue.git', branch: 'main'
```
Open terminal, and run this : 
```bash
cd your_ruby_application
bundle install
```

Make redis so that it can save on disk, in case the server dies or crashes :

```bash
sudo nano /etc/redis/redis.conf
# Fill in /etc/redis/redis.conf as below :
# Untuk RDB
save 900 1    # Simpan jika ada 1 perubahan dalam 900 detik (15 menit)
save 300 10   # Simpan jika ada 10 perubahan dalam 300 detik (5 menit)
save 60 10000 # Simpan jika ada 10000 perubahan dalam 60 detik (1 menit)

# Untuk AOF
appendonly yes
appendfsync everysec # Sinkronisasi ke disk setiap detik
# end of file /etc/redis/redis.conf

sudo systemctl restart redis-server
```

## Usage

To add consumer, you can add this code :

```ruby
require 'pistonqueue'

Pistonqueue::Consumer.run do |data|
    # logic for processing or storing data from the Redis queue.
end
```

Consumer is a class for retrieving and processing data from the redis queue. The following is an example code for consumer implementation :

```ruby
# consumer.rb
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
```

How to make 'consumer.rb' run in systemd :
```bash
cd /etc/systemd/system/
sudo touch pistonqueue_consumer.service
which bundler # bundler-installation-location
which ruby # ruby-installation-location
sudo nano pistonqueue_consumer.service
# Fill in pistonqueue_consumer.service as below :
[Unit]
Description=Hybrid Ruby Worker Service
After=network.target redis-server.service

[Service]
User=blackedet # your username on the server/computer
WorkingDirectory=/home/blackedet/MyWorks/test3 # location of your project folder
Environment="REDIS_URL=redis://localhost:6379" # env for redis url
ExecStartPre=/home/blackedet/.local/share/mise/installs/ruby/3.4.5/bin/bundle install # <bundler-installation-location> install
ExecStart=/home/blackedet/.local/share/mise/installs/ruby/3.4.5/bin/bundle exec /home/blackedet/.local/share/mise/installs/ruby/3.4.5/bin/ruby consumer.rb # <bundler-installation-location> <ruby-installation-location> consumer.rb
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
# end of file pistonqueue_consumer.service
ctrl + o 
sudo systemctl daemon-reload
sudo systemctl start pistonqueue_consumer
sudo systemctl enable pistonqueue_consumer
```

How to see your service status in systemd :
```bash
sudo systemctl status pistonqueue_consumer.service
```

How to view your service logs in systemd :
```bash
sudo journalctl -u pistonqueue_consumer.service -f
```

How to restart the service :
```bash
sudo systemctl daemon-reload
sudo systemctl restart pistonqueue_consumer
```

To add a producer, you can add this code :

```ruby
require 'pistonqueue'

Pistonqueue::Producer.add_to_queue(request_body)
```

Producer is a class for storing request body in a queue in redis. The following is an example of its application in controllers :

```ruby
# producer.rb
require 'sinatra'
require 'json'
require 'pistonqueue'

post '/sync' do
    begin
        request_body = JSON.parse(request.body.read)
        Pistonqueue::Producer.add_to_queue(request_body)

        content_type :json
        { data: true }.to_json
    rescue => e
        content_type :json
        status 500
        return { error: e.message }.to_json
    end
end

# bundle install
# bundle exec ruby producer.rb
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/solehudinmq/pistonqueue.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
