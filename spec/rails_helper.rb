require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  minimum_coverage line: 95
end

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"

Rails.root.glob("spec/support/**/*.rb").sort.each { |f| require f }

# No spec may reach the real network; every upstream call must be stubbed.
WebMock.disable_net_connect!

RSpec.configure do |config|
  config.use_active_record = false
  config.filter_rails_from_backtrace!
  config.include ActiveSupport::Testing::TimeHelpers

  # Rails.cache also backs Rack::Attack counters; start every example clean.
  config.before { Rails.cache.clear }
end
