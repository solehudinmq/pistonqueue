# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in pistonqueue.gemspec
gemspec

gem "async"
gem "redis"
gem "connection_pool"
gem "logger"

group :development, :test do
  gem "byebug"
end

group :development do
  gem "irb"
  gem "rake"
  gem "rubocop"
end

group :test do
  gem "rspec"
  gem "async-rspec"
end