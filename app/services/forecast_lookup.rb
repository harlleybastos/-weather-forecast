# Geocodes are cached by address; forecasts are shared across each postal code.
# Upstream exceptions and unmatched addresses are not cached.
class ForecastLookup
  class Error < StandardError; end
  class AddressNotFound < Error; end
  class PostalCodeNotFound < Error; end

  Result = Data.define(:location, :forecast, :cached, :fetched_at) do
    alias_method :cached?, :cached
  end

  CACHE_VERSION = "v1"

  # While one request refreshes an expired entry, concurrent requests keep
  # receiving the stale value for this long instead of all hitting upstream.
  RACE_CONDITION_TTL = 10.seconds

  def initialize(
    geocoder: Geocoding::NominatimClient.new,
    weather: Forecasts::OpenMeteoClient.new,
    cache: Rails.cache,
    forecast_ttl: Rails.configuration.x.forecast.cache_ttl,
    geocode_ttl: Rails.configuration.x.geocode.cache_ttl
  )
    @geocoder = geocoder
    @weather = weather
    @cache = cache
    @forecast_ttl = forecast_ttl
    @geocode_ttl = geocode_ttl
  end

  def call(address)
    location = geocode(address)
    raise PostalCodeNotFound, "No postal code found for #{location.display_name}" unless location.postal_code?

    cached = true
    entry = cache.fetch(forecast_key(location), expires_in: forecast_ttl, race_condition_ttl: RACE_CONDITION_TTL) do
      cached = false
      { forecast: weather.fetch(latitude: location.latitude, longitude: location.longitude), fetched_at: Time.current }
    end

    Result.new(location: location, forecast: entry.fetch(:forecast), cached: cached, fetched_at: entry.fetch(:fetched_at))
  end

  private

  attr_reader :geocoder, :weather, :cache, :forecast_ttl, :geocode_ttl

  def geocode(address)
    location = cache.fetch(geocode_key(address), expires_in: geocode_ttl, skip_nil: true) do
      geocoder.locate(address)
    end
    location || raise(AddressNotFound, "No match for the given address")
  end

  # Addresses are hashed: keys stay short and bounded, and raw user input
  # (potentially PII) never ends up in Redis key names.
  def geocode_key(address)
    "geocode/#{CACHE_VERSION}/#{Digest::SHA256.hexdigest(address.downcase.squish)}"
  end

  def forecast_key(location)
    "forecast/#{CACHE_VERSION}/#{location.postal_code_key}"
  end
end
