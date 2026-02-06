# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in pistonqueue.gemspec
gemspec

gem "async"
gem "redis"
gem "async-redis"

group :development, :test do
  gem "byebug"
end

group :development do
  gem "irb"
  gem "rake", "~> 13.0"
  gem "rubocop", "~> 1.21"
end

group :test do
  gem "rspec", "~> 3.0"
end