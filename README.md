# Pistonqueue

Pistonqueue is a ruby library for handling backpressure using a webhook mechanism in our backend systems. Each incoming request is first passed to the message broker and then consumed by the consumer. Each task is executed using Ruby's concurrency capabilities.

Currently, the available message broker mechanisms are :
- redis stream.

## High Flow

Potential problems if our application is unable to handle backpressure issues :

![Logo Ruby](./high_flow/pistonqueue-problem.jpg)

With pistonqueue, our application is now able to handle as many requests as possible :

![Logo Ruby](./high_flow/pistonqueue-solution-redis-stream.jpg)

## Requirement

Minimum software version that must be installed on your device :
- ruby 3.0

- redis 6.2

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

## Usage

### Redis Setup (optional)

Make redis so that it can save on disk, in case the server dies or crashes. For more details, you can see the following example : [example/redis_disk.txt](./example/redis_disk.txt)

### Library Setup

Before using this library, do initial setup first. Here's an example :

```ruby
# config.rb
require 'pistonqueue'

::Pistonqueue.configure do |config|
  config.io_light_fiber = <your-value> # default value : 500
  config.io_medium_fiber = <your-value> # default value : 100
  config.io_heavy_fiber = <your-value> # default value : 10
  config.cpu_fiber = <your-value> # default value : 1
  config.redis_url = <your-value> # default value : 'redis://127.0.0.1:6379'
  config.redis_block_duration = <your-value> # default value : 2000
  config.redis_batch_size = <your-value> # default value : 10
  config.max_local_retry = <your-value> # default value : 1
  config.max_retry = <your-value> # default value : 3
  config.maxlen = <your-value> # default value : 10000
  config.connection_pool_size = <your-value> # default value : 5
  config.connection_timeout = <your-value> # default value : 1
  config.redis_min_idle_time = <your-value> # default value : 10000
end
```

Parameter description :
- io_light_fiber : total fiber to run light i/o bound tasks, recommendation : 500-2000.
- io_medium_fiber : total fiber to perform medium bound i/o tasks, recommendation : 100-500.
- io_heavy_fiber : total fiber to run heavy i/o bound tasks, recommendation : 10-50.
- cpu_fiber : total fiber to run cpu bound tasks, recommendation : 1.
- redis_url : your redis url.
- redis_block_duration : how long (in milliseconds) this connection will "idly wait" if there are no new messages in the redis stream at that time.
- redis_batch_size : the maximum number of messages to be retrieved in one command in redis.
- max_local_retry : maximum number of retries can be made at the consumer.
- max_retry : maximum retry used for retry processes outside the main consumer.
- maxlen : if the number of messages has reached the maxlen limit, redis will automatically delete the oldest messages so that new messages can enter, recommendation : small/medium : 10000-50000 / high traffic : 100000 - 500000 / log/audit trail : 1000000+.
- connection_pool_size : the maximum number of connections that the pool can open and keep alive (persistent).
- connection_timeout : the maximum duration (in seconds) a thread is willing to wait/queue until a connection is available.
- redis_min_idle_time : retrieve messages that have been in the pending list for at least x millisecond, recommendation : 10000-30000.

For more details, you can see the following example : [example/config.rb](./example/config.rb).

### Consumer

Consumer is an application to retrieve data from message broker, and process your business logic by utilizing concurrency in ruby. Here's an example :

```ruby
require 'pistonqueue'

require_relative 'config'

consumer = ::Pistonqueue::Consumer.new(driver: <your-driver>)
consumer.perform(topic: <your-topic>, task_type: <your-task-type>, is_retry: <your-is-retry>, group: <your-group>, consumer: <your-consumer>) do |data|
  # your logic here
end
```

Parameter description :
- driver : types of message brokers for implementing back pressure, for example : :redis_stream.
- topic : target 'topic' to send data to the message broker, for example : 'topic_io'.
- task_type : the type of task that will be performed on the consumer, for example: :io_bound_light / :io_bound_medium / :io_bound_heavy / :cpu_bound.
- is_retry : this consumer is intended for retry or main process, for example : true / false.
- group : grouping multiple workers to work on the same data stream (topic) without competing for messages, for example : 'group_io'.
- consumer : provides a unique identity to each application instance or thread you run, for example : 'consumer_io'.

For more details, you can see the following example : 
- consumer for light i/o bound tasks : [example/simulations/consumer_1.rb](./example/simulations/consumer_1.rb).
- consumer for medium i/o bound tasks : [example/simulations/consumer_2.rb](./example/simulations/consumer_2.rb).
- consumer for heavy i/o bound tasks : [example/simulations/consumer_3.rb](./example/simulations/consumer_3.rb).
- consumer for cpu bound tasks : [example/simulations/consumer_4.rb](./example/simulations/consumer_4.rb).
- consumer for retry performed outside the main consumer : [example/simulations/consumer_retry.rb](./example/simulations/consumer_retry.rb).

How to make 'consumer' run in systemd service : [example/run_consumer_in_systemd.txt](./example/run_consumer_in_systemd.txt).

Note: 
- if the main process fails, the data will be saved in the topic `<topic-name>_retry`.
- if the retry process outside the main consumer still fails, the data will be sent to the topic. `<topic-name>_dlq`.

### Producer

Producer is an application for sending data to the message broker, here's an example :

```ruby
require 'pistonqueue'

require_relative 'config'

producer = ::Pistonqueue::Producer.new(driver: <your-driver>)
producer.perform(topic: <your-topic>, data: <request-body>)
```

Parameter description :
- driver : types of message brokers for implementing back pressure, for example : :redis_stream.
- topic : target 'topic' to send data to the message broker, for example : 'topic_io'.
- data : hash object to send to message broker, for example : 

```json
{
  "user_id": 1,
  "total_amount": 20000
}
```

For more details, you can see the following example : [example/app.rb](./example/app.rb).

### Dead Letter

If the retry process still fails, the data will be stored in the dead letter. Here's an example :

```ruby
require 'pistonqueue'

require_relative 'config'

dead_letter = ::Pistonqueue::DlqConsumer.new(driver: <your-driver>)
dead_letter.perform(topic: <your-topic>, task_type: <your-task-type>, is_archive: <your-is-archive>, group: <your-group>, consumer: <your-consumer>) do |original_id, original_data, error, failed_at|
  # your logic here
end
```

Parameter description :
- driver : types of message brokers for implementing back pressure, for example : :redis_stream.
- topic : target 'topic' to send data to the message broker, for example : 'topic_io'.
- task_type : the type of task that will be performed on the consumer, for example: :io_bound_light / :io_bound_medium / :io_bound_heavy / :cpu_bound.
- is_archive : consumer dead letter that still fails in the process do the process manually, for example : true / false.
- group : grouping multiple workers to work on the same data stream (topic) without competing for messages, for example : 'group_io'.
- consumer : provides a unique identity to each application instance or thread you run, for example : 'consumer_io'.

For more details, you can see the following example : 
- consumer for dead letter process : [example/simulations/consumer_dead_letter.rb](./example/simulations/consumer_dead_letter.rb).
- consumer for dead letter archive process : [example/simulations/consumer_dead_letter_archive.rb](./example/simulations/consumer_dead_letter_archive.rb).

Note: if the dead letter process still fails, the data will be saved in the topic `<topic-name>_dlq_archive`.

### Handle Data Stuck
In unpredictable situations (e.g., if consumer crash), the data can be categorized as stuck. To retrieve and process this data, we can do the following :

1. data stuck when the main or retry consumer process is carried out, here's an example :

```ruby
require 'pistonqueue'

require_relative 'config'

recovery = ::Pistonqueue::RecoveryConsumer.new(driver: <your-driver>)
recovery.perform(topic: <your-topic>, task_type: <your-task-type>, is_retry: <your-is-retry>, group: <your-group>, consumer: <your-consumer>) do |data|
  # your logic here
end
```

Parameter description :
- driver : types of message brokers for implementing back pressure, for example : :redis_stream.
- topic : target 'topic' to send data to the message broker, for example : 'topic_io'.
- task_type : the type of task that will be performed on the consumer, for example: :io_bound_light / :io_bound_medium / :io_bound_heavy / :cpu_bound.
- is_retry : this consumer is intended for retry or main process, for example : true / false.
- group : grouping multiple workers to work on the same data stream (topic) without competing for messages, for example : 'group_io'.
- consumer : provides a unique identity to each application instance or thread you run, for example : 'consumer_io'.

For more details, you can see the following example : 
- pending data in the main process : [example/simulations/consumer_pending.rb](./example/simulations/consumer_pending.rb).
- pending data in the retry process : [example/simulations/consumer_pending_retry.rb](./example/simulations/consumer_pending_retry.rb).

2. data stuck when the consumer dead letter process is carried out, here's an example :

```ruby
require 'pistonqueue'

require_relative 'config'

recovery = ::Pistonqueue::RecoveryConsumer.new(driver: <your-driver>)
recovery.dead_letter_perform(topic: <your-topic>, task_type: <your-task-type>, group: <your-group>, consumer: <your-consumer>) do |original_id, original_data, error, failed_at|
  # your logic here
end
```

Parameter description :
- driver : types of message brokers for implementing back pressure, for example : :redis_stream.
- topic : target 'topic' to send data to the message broker, for example : 'topic_io'.
- task_type : the type of task that will be performed on the consumer, for example: :io_bound_light / :io_bound_medium / :io_bound_heavy / :cpu_bound.
- group : grouping multiple workers to work on the same data stream (topic) without competing for messages, for example : 'group_io'.
- consumer : provides a unique identity to each application instance or thread you run, for example : 'consumer_io'.

For more details, you can see the following example : [example/simulations/consumer_pending_dead_letter.rb](./example/simulations/consumer_pending_dead_letter.rb).

How to make 'data stuck consumer' run in systemd service : [example/run_consumer_pending_in_systemd.txt](./example/run_consumer_pending_in_systemd.txt).

## How to do a Stress Test

Make sure 'consumer' is running in the systemd service, then to send a lot of data to the message broker, you can follow these steps : 
- normal flow : [example/run_producer.txt](./example/run_producer.txt).
- flow data stuck : [example/run_producer_pending.txt](./example/run_producer_pending.txt).

or if you want to do it on localhost only, here's an example : [example/test_on_localhost.txt](./example/test_on_localhost.txt).

## Example Implementation in Your Application

For examples of applications that use this gem, you can see them here : [example](./example).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/solehudinmq/pistonqueue.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
