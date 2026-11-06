source "https://rubygems.org"

gem "rails", "~> 8.1.4"
gem "propshaft"
gem "puma", ">= 5.0"

gem "faraday", "~> 2.12"
gem "faraday-retry", "~> 2.2"
gem "redis", "~> 5.3"
gem "rack-attack", "~> 6.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "bundler-audit", require: false
  gem "rspec-rails", "~> 8.0"
end

group :test do
  gem "simplecov", require: false
  gem "webmock", "~> 3.24"
end

group :development do
  gem "web-console"
end
