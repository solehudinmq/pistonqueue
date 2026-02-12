# case for consumers with web scraping.
require 'pistonqueue'
require 'async'
require 'async/http/internet'
require 'nokogiri'

require_relative '../config'

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