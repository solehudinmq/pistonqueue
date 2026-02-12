# case for consumers with web scraping.
require 'pistonqueue'
require 'async'
require 'async/http/internet'
require 'nokogiri'
require 'dotenv'

Dotenv.load('../.env')

::Pistonqueue.configure do |config|
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

internet = Async::HTTP::Internet.new
BASE_URL = "https://webscraper.io/test-sites/e-commerce/static/computers/laptops"
results = []

consumer = ::Pistonqueue::Consumer.new(driver: :redis_stream)
consumer.subscribe(topic: 'topic_io_heavy', task_type: :io_bound_heavy, group: 'group-3', consumer: 'consumer-3') do |data|  
  begin
    (1..3).each do |page_num|
      url = "#{BASE_URL}?page=#{page_num}"

      begin
        response = internet.get(url)
        html_content = response.read
        doc = Nokogiri::HTML(html_content)

        doc.css('.thumbnail').each do |card|
          item = {
            title: card.css('.title').text.strip,
            price: card.css('.price').text.strip,
            description: card.css('.description').text.strip,
            page: page_num
          }
          results << item
          puts "✅ Found: #{item[:title][0..20]}... - #{item[:price]}"
        end

      rescue => e
        puts "❌ Error on the page #{page_num}: #{e.message}"
      ensure
        response&.close
      end

      puts "\n🏁 Scraping completed!"
      puts "Total data obtained: #{results.size}"
    end
  end
end

# run this command :
# - open terminal
# - cd example/simulations
# - bundle install
# - bundle exec ruby consumer_3.rb