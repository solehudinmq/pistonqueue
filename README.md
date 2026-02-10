# Pistonqueue

Pistonqueue is a Ruby library for handling backpressure using a webhook mechanism in our backend systems. Each incoming request is first passed to the message broker and then consumed by the consumer. Each task is executed using Ruby's concurrency capabilities.

Currently, the available message broker mechanisms are :
- redis stream.

## High Flow

Potential problems if our application is unable to handle backpressure issues :

![Logo Ruby](https://github.com/solehudinmq/pistonqueue/blob/development/high_flow/pistonqueue-problem.jpg)

With Pistonqueue, our application is now able to handle as many requests as possible :

![Logo Ruby](https://github.com/solehudinmq/pistonqueue/blob/development/high_flow/pistonqueue-solution-redis-stream.jpg)

## Requirement

The minimum version of Ruby that must be installed is 3.0.

Requires dependencies to the following gems :
- async

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

Make redis so that it can save on disk, in case the server dies or crashes. For more details, you can see the following example : [example/redis_disk.txt](https://github.com/solehudinmq/pistonqueue/blob/development/example/redis_disk.txt).

## Usage

### Consumer

Consumer is an application to retrieve data from redis stream, and process your business logic by utilizing concurrency in ruby. Here's an example :

```ruby
require 'pistonqueue'

Pistonqueue.configure do |config|
  config.io_light_fiber = <your-value>
  config.io_medium_fiber = <your-value>
  config.io_heavy_fiber = <your-value>
  config.cpu_fiber = <your-value>
  config.redis_url = <your-value>
  config.redis_block_duration = <your-value>
  config.redis_batch_size = <your-value>
  config.max_local_retry = <your-value>
  config.max_retry = <your-value>
  config.maxlen = <your-value>
  config.connection_pool_size = <your-value>
  config.connection_timeout = <your-value>
end

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: <your-topic>, task_type: <your-task-type>, is_retry: <your-is-retry>, group: <your-group>, consumer: <your-consumer>) do |data|
  # your logic here
end
```

Parameter description :
- topic : target 'topic' to send data to the message broker, for example : 'topic_io'.
- task_type : the type of task that will be performed on the consumer, for example: :io_bound_light / :io_bound_medium / :io_bound_heavy / :cpu_bound.
- is_retry : this consumer is intended for retry or main process, for example : true / false.
- group : grouping multiple workers to work on the same data stream (topic) without competing for messages, for example : 'group_io'.
- consumer : provides a unique identity to each application instance or thread you run, for example : 'consumer_io'.

For more details, you can see the following example : 
- consumer for light i/o bound tasks : [example/simulations/consumer_1.rb](https://github.com/solehudinmq/pistonqueue/blob/development/example/simulations/consumer_1.rb).
- consumer for medium i/o bound tasks : [example/simulations/consumer_2.rb](https://github.com/solehudinmq/pistonqueue/blob/development/example/simulations/consumer_2.rb).
- consumer for heavy i/o bound tasks : [example/simulations/consumer_3.rb](https://github.com/solehudinmq/pistonqueue/blob/development/example/simulations/consumer_3.rb).
- consumer for cpu bound tasks : [example/simulations/consumer_4.rb](https://github.com/solehudinmq/pistonqueue/blob/development/example/simulations/consumer_4.rb).
- consumer to retry process : [example/simulations/consumer_retry.rb](https://github.com/solehudinmq/pistonqueue/blob/development/example/simulations/consumer_retry.rb).
- consumer for dead letter process : [example/simulations/consumer_dead_letter.rb](https://github.com/solehudinmq/pistonqueue/blob/development/example/simulations/consumer_dead_letter.rb).

How to make 'consumer' run in systemd service : [example/run_consumer_in_systemd.txt](https://github.com/solehudinmq/pistonqueue/blob/development/example/run_consumer_in_systemd.txt).

### Producer

Producer is an application for sending data to the message broker, here's an example :

```ruby
require 'pistonqueue'

Pistonqueue.configure do |config|
  config.io_light_fiber = <your-value>
  config.io_medium_fiber = <your-value>
  config.io_heavy_fiber = <your-value>
  config.cpu_fiber = <your-value>
  config.redis_url = <your-value>
  config.redis_block_duration = <your-value>
  config.redis_batch_size = <your-value>
  config.max_local_retry = <your-value>
  config.max_retry = <your-value>
  config.maxlen = <your-value>
  config.connection_pool_size = <your-value>
  config.connection_timeout = <your-value>
end

producer = ::Pistonqueue::Producer.new(driver: :redis_stream)
producer.publish(topic: <your-topic>, data: <request-body>)
```

Parameter description :
- topic : target 'topic' to send data to the message broker, for example : 'topic_io'.
- request_body : data in hash form that will be sent to the Redis queue, for example : 

```json
{
  "user_id": 1,
  "total_amount": 20000
}
```

For more details, you can see the following example : [example/app.rb](https://github.com/solehudinmq/pistonqueue/blob/development/example/app.rb).

## How to do a Stress Test

For more details, you can see the following example : [example/simulations/producer.rb](https://github.com/solehudinmq/pistonqueue/blob/development/example/simulations/producer.rb)

## Example Implementation in Your Application

For examples of applications that use this gem, you can see them here : [example](https://github.com/solehudinmq/pistonqueue/tree/development/example).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/solehudinmq/pistonqueue.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
