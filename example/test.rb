require 'httparty'
require 'json'

1000.times do |i|
  begin
    puts "Panggil Api ke - #{i}"

    HTTParty.post("http://localhost:4567/sync", 
      body: {
        "user_id": i,
        "total_amount": i * 100
      }.to_json, 
      headers: { 'Content-Type' => 'application/json' },
      timeout: 3
    )
  rescue => e
    puts "Error di proses ke : #{i}"
  end
end

puts "Selesai"

# note : 
# 1. must run : bundle exec ruby ​​app.rb
# 2. bundle exec test.rb