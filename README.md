# Pistonqueue

Pistonqueue is a Ruby library for handling backpressure conditions, using queue solutions and leveraging concurrency and parallelism to process each incoming request. This allows our applications to handle high traffic without worrying about overloading our systems.

Pistonqueue utilizes a queue to receive every incoming request and maximizes the execution of each task through concurrency and parallelism. This optimizes system performance when handling requests from third-party applications.

## High Flow

Potential problems if our application is unable to handle backpressure issues :

![Logo Ruby](https://github.com/solehudinmq/pistonqueue/blob/development/high_flow/Pistonqueue-problem.jpg)

With Pistonqueue, our application is now able to handle as many requests as possible :

![Logo Ruby](https://github.com/solehudinmq/pistonqueue/blob/development/high_flow/Pistonqueue-solution.jpg)

## Requirement

The minimum version of Ruby that must be installed is 3.0.

Requires dependencies to the following gems :
- concurrent-ruby

- redis

- connection_pool

## Installation

Add this line to your application's Gemfile :

```ruby
# Gemfile
gem 'pistonqueue', git: 'git@github.com:solehudinmq/pistonqueue.git', branch: 'main'
```

Open terminal, and run this : 

```bash
cd your_ruby_application
bundle install
```

## Redis Setup to Save Data to Disk

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

For more details, you can see the following example : [example/redis_disk.txt](https://github.com/solehudinmq/pistonqueue/blob/development/example/redis_disk.txt).

## Usage

### Consumer

Consumer is an application that receives data from a Redis queue. Here's an example :

```ruby
require 'pistonqueue'

Pistonqueue::Consumer.run do |data|
  # logic for processing or storing data from the Redis queue.
end
```

For more details, you can see the following example : [example/consumer.rb](https://github.com/solehudinmq/pistonqueue/blob/development/example/consumer.rb).

How to make 'consumer.rb' run in systemd :

```bash
cd /etc/systemd/system/
sudo touch your_consumer.service
which bundler # bundler-installation-location
which ruby # ruby-installation-location

sudo systemctl stop your_consumer.service

sudo nano your_consumer.service
# Fill in your_consumer.service as below :
[Unit]
Description=<service-description>
After=network.target redis-server.service

[Service]
User=<your-server-username>
WorkingDirectory=<your-consumer-project-folder>
Environment="REDIS_URL=redis://<username>:<password>@<host>:<port>/<db>"
ExecStartPre=<bundler-installation-location> install
ExecStart=<bundler-installation-location> <ruby-installation-location> consumer.rb
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
# end of file your_consumer.service

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

For more details, you can see the following example : 

- Run consumer in systemd : [example/run_consumer_in_systemd.txt](https://github.com/solehudinmq/pistonqueue/blob/development/example/run_consumer_in_systemd.txt).

- Consumer status in systemd : [example/consumer_status.txt](https://github.com/solehudinmq/pistonqueue/blob/development/example/consumer_status.txt).

- Consumer logs in systemd : [example/consumer_logs.txt](https://github.com/solehudinmq/pistonqueue/blob/development/example/consumer_logs.txt).

- Consumer restart in systemd : [example/consumer_restart.txt](https://github.com/solehudinmq/pistonqueue/blob/development/example/consumer_restart.txt).

### Producer

A producer is an application used to send requests to a Redis queue. Here's an example :

```ruby
require 'pistonqueue'

Pistonqueue::Producer.add_to_queue(request_body)
```

Parameter description :
- request_body : data in hash form that will be sent to the Redis queue. Example : 

```json
{
  "user_id": 1,
  "total_amount": 20000
}
```

For more details, you can see the following example : [example/app.rb](https://github.com/solehudinmq/pistonqueue/blob/development/example/app.rb).

## How to do Bulk Insert

For more details, you can see the following example : [example/test.rb](https://github.com/solehudinmq/pistonqueue/blob/development/example/test.rb)

## Example Implementation in Your Application

For examples of applications that use this gem, you can see them here : [example](https://github.com/solehudinmq/pistonqueue/tree/development/example).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/solehudinmq/pistonqueue.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
