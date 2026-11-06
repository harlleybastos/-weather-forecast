require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module WeatherForecast
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.generators.system_tests = nil

    config.x.http.open_timeout = Float(ENV.fetch("HTTP_OPEN_TIMEOUT", 2))
    config.x.http.read_timeout = Float(ENV.fetch("HTTP_READ_TIMEOUT", 5))
    config.x.http.retry_interval = Float(ENV.fetch("HTTP_RETRY_INTERVAL", 0.25))

    config.x.nominatim.base_url = ENV.fetch("NOMINATIM_BASE_URL", "https://nominatim.openstreetmap.org")
    # Nominatim's usage policy requires an identifying User-Agent.
    config.x.nominatim.user_agent = ENV.fetch("NOMINATIM_USER_AGENT", "weather-forecast-challenge/1.0")
    # Restrict bare ZIP codes to the US; blank searches worldwide.
    config.x.nominatim.country_codes = ENV.fetch("NOMINATIM_COUNTRY_CODES", "us")

    config.x.open_meteo.base_url = ENV.fetch("OPEN_METEO_BASE_URL", "https://api.open-meteo.com")

    config.x.forecast.cache_ttl = Integer(ENV.fetch("FORECAST_CACHE_TTL_SECONDS", 30.minutes.to_i)).seconds
    config.x.geocode.cache_ttl = Integer(ENV.fetch("GEOCODE_CACHE_TTL_SECONDS", 7.days.to_i)).seconds
  end
end
