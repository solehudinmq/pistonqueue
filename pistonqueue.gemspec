# frozen_string_literal: true

require_relative "lib/pistonqueue/version"

Gem::Specification.new do |spec|
  spec.name = "pistonqueue"
  spec.version = Pistonqueue::VERSION
  spec.authors = ["SolehMQ"]
  spec.email = ["solehudinmq@gmail.com"]

  spec.summary = "Pistonqueue is a Ruby library for handling backpressure conditions, using queue solutions and leveraging concurrency and parallelism to process each incoming request. This allows our applications to handle high traffic without worrying about overloading our systems."
  spec.description = "Pistonqueue utilizes a queue to receive every incoming request and maximizes the execution of each task through concurrency and parallelism. This optimizes system performance when handling requests from third-party applications."
  spec.homepage = "https://github.com/solehudinmq/pistonqueue"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "concurrent-ruby", "~> 1.1"
  spec.add_dependency "redis", "~> 5.0"
  spec.add_dependency "connection_pool", "~> 2.4"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
