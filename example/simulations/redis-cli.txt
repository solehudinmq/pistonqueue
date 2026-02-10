1. how to check whether the data has entered the redis stream :
  - open a new tab
  - redis-cli
  - xrevrange topic_io_light + - count 10000
  - xrevrange topic_io_medium + - count 5000
  - xrevrange topic_io_heavy + - count 1000
  - xrevrange topic_cpu + - count 100

2. how to check pending data in redis stream :
  - open a new tab
  - redis-cli
  - XPENDING topic_io_light group-1 + - 10000
  - XPENDING topic_io_medium group-2 + - 5000
  - XPENDING topic_io_heavy group-3 + - 1000
  - XPENDING topic_cpu group-4 + - 100

3. how to delete all data in redis :
  - FLUSHALL
