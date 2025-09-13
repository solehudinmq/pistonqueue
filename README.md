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
# For RDB
save <second> <total_data_change>
save <second> <total_data_change>
save <second> <total_data_change>

# For AOF
appendonly yes
appendfsync everysec # Sync to disk every second
# end of file /etc/redis/redis.conf

sudo systemctl restart redis-server
```

Example : 

```bash
sudo nano /etc/redis/redis.conf
# Fill in /etc/redis/redis.conf as below :
# For RDB
save 900 1    # Save if there is 1 change in 900 seconds (15 minutes)
save 300 10   # Save if there are 10 changes in 300 seconds (5 minutes)
save 60 10000 # Save if there are 10000 changes in 60 seconds (1 minute)

# For AOF
appendonly yes
appendfsync everysec # Sync to disk every second
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
# order.rb

require 'sinatra'
require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/development.sqlite3'
)

Dir.mkdir('db') unless File.directory?('db')

# Model
class Order < ActiveRecord::Base
end

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
```

```ruby
# consumer.rb
require 'pistonqueue'

require_relative 'order'

class ConsumerService
    def self.pull
        Pistonqueue::Consumer.run do |data|
            puts "Data from redis queue : #{data}"
            order = Order.new(user_id: data["user_id"], order_date: Date.today, total_amount: data["total_amount"])
            order.save
        end
    end
end

ConsumerService.pull
```

How to make 'consumer.rb' run in systemd :
```bash
cd /etc/systemd/system/
sudo touch your_consumer.service
which bundler # bundler-installation-location
which ruby # ruby-installation-location
sudo nano your_consumer.service
# Fill in your_consumer.service as below :
[Unit]
Description=<service-description>
After=network.target redis-server.service

[Service]
User=<your-server-username>
WorkingDirectory=<consumer-file>
Environment="REDIS_URL=redis://<username>:<password>@<host>:<port>/<db>."
ExecStartPre=<bundler-installation-location> install
ExecStart=<bundler-installation-location> <ruby-installation-location> consumer.rb
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
# end of file pistonqueue_consumer.service

sudo systemctl daemon-reload
sudo systemctl start your_consumer.service
sudo systemctl enable your_consumer.service
```

How to see your service status in systemd :
```bash
sudo systemctl status your_consumer.service
```

How to view your service logs in systemd :
```bash
sudo journalctl -u your_consumer.service -f
```

How to restart the service :
```bash
sudo systemctl daemon-reload
sudo systemctl restart your_consumer.service
```

Example : 

```bash
cd /etc/systemd/system/
sudo touch pistonqueue_consumer.service
which bundler # bundler-installation-location
which ruby # ruby-installation-location
sudo nano pistonqueue_consumer.service
# Fill in pistonqueue_consumer.service as below :
[Unit]
Description=Ruby service to consume and process data from redis queue
After=network.target redis-server.service

[Service]
User=blackedet # your username on the server/computer
WorkingDirectory=/home/blackedet/MyWorks/test # location of your project folder
Environment="REDIS_URL=redis://localhost:6379" # env for redis url
ExecStartPre=/home/blackedet/.local/share/mise/installs/ruby/3.4.5/bin/bundle install # <bundler-installation-location> install
ExecStart=/home/blackedet/.local/share/mise/installs/ruby/3.4.5/bin/bundle exec /home/blackedet/.local/share/mise/installs/ruby/3.4.5/bin/ruby consumer.rb # <bundler-installation-location> <ruby-installation-location> consumer.rb
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
# end of file pistonqueue_consumer.service

sudo systemctl daemon-reload
sudo systemctl start pistonqueue_consumer.service
sudo systemctl enable pistonqueue_consumer.service
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
sudo systemctl restart pistonqueue_consumer.service
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
