require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # TLS terminates at the reverse proxy.
  config.assume_ssl = ENV.fetch("ASSUME_SSL", "true") == "true"
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"

  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Share forecasts across workers. Short timeouts let Redis failures fall
  # back to live lookups without holding up requests for long.
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    namespace: "weather",
    connect_timeout: 1,
    read_timeout: 0.5,
    write_timeout: 0.5,
    reconnect_attempts: 1,
    pool: { size: Integer(ENV.fetch("RAILS_MAX_THREADS", 3)), timeout: 1 },
    error_handler: ->(method:, returning:, exception:) {
      Rails.logger.warn("[cache] #{method} failed (#{exception.class}: #{exception.message}); returning #{returning.inspect}")
    }
  }

  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false
  config.i18n.fallbacks = true
end
