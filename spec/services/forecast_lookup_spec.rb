require "rails_helper"

RSpec.describe ForecastLookup do
  subject(:lookup) { described_class.new(geocoder: geocoder, weather: weather, cache: cache) }

  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:geocoder) { instance_double(Geocoding::NominatimClient, locate: cupertino) }
  let(:weather) { instance_double(Forecasts::OpenMeteoClient, fetch: forecast) }

  let(:cupertino) { build_location(postal_code: "95014", display_name: "1 Infinite Loop, Cupertino") }
  let(:forecast) do
    Forecast.new(
      temperature: 72.8, feels_like: 70.0, humidity: 30.0, wind_speed: 5.0, weather_code: 0,
      observed_at: Time.current, temperature_unit: "°F", wind_speed_unit: "mph",
      days: [ Forecast::Day.new(date: Date.current, high: 75.0, low: 50.0, weather_code: 0, precipitation_probability: 0) ]
    )
  end

  def build_location(postal_code:, display_name: "Somewhere", latitude: 37.33, longitude: -122.03, country_code: "us")
    Location.new(display_name:, postal_code:, country_code:, latitude:, longitude:)
  end

  it "returns a live result on the first lookup" do
    result = lookup.call("1 Infinite Loop, Cupertino, CA")

    expect(result).to have_attributes(location: cupertino, forecast: forecast)
    expect(result).not_to be_cached
    expect(weather).to have_received(:fetch).with(latitude: 37.33, longitude: -122.03)
  end

  it "serves a cached result for a subsequent lookup within 30 minutes" do
    freeze_time do
      lookup.call("1 Infinite Loop, Cupertino, CA")
      travel 29.minutes

      result = lookup.call("1 Infinite Loop, Cupertino, CA")

      expect(result).to be_cached
      expect(result.fetched_at).to eq(29.minutes.ago)
      expect(weather).to have_received(:fetch).once
    end
  end

  it "shares the cache between different addresses in the same ZIP code" do
    other_address = build_location(postal_code: "95014", display_name: "Apple Park, Cupertino", latitude: 37.3349, longitude: -122.009)
    allow(geocoder).to receive(:locate).with("Apple Park").and_return(other_address)

    lookup.call("1 Infinite Loop, Cupertino, CA")
    result = lookup.call("Apple Park")

    expect(result).to be_cached
    expect(result.location).to eq(other_address)
    expect(weather).to have_received(:fetch).once
  end

  it "keeps separate entries for different ZIP codes" do
    allow(geocoder).to receive(:locate).with("New York").and_return(build_location(postal_code: "10001"))

    lookup.call("1 Infinite Loop, Cupertino, CA")
    result = lookup.call("New York")

    expect(result).not_to be_cached
    expect(weather).to have_received(:fetch).twice
  end

  it "keys forecasts by country so identical postcodes don't collide" do
    allow(geocoder).to receive(:locate).with("Berlin").and_return(build_location(postal_code: "95014", country_code: "de"))

    lookup.call("1 Infinite Loop, Cupertino, CA")

    expect(lookup.call("Berlin")).not_to be_cached
  end

  it "fetches fresh data once the 30 minute TTL has elapsed" do
    lookup.call("1 Infinite Loop, Cupertino, CA")

    travel(30.minutes + ForecastLookup::RACE_CONDITION_TTL + 1.second) do
      expect(lookup.call("1 Infinite Loop, Cupertino, CA")).not_to be_cached
    end
    expect(weather).to have_received(:fetch).twice
  end

  it "honours a configurable forecast TTL" do
    short_lived = described_class.new(geocoder:, weather:, cache:, forecast_ttl: 1.minute)
    short_lived.call("1 Infinite Loop, Cupertino, CA")

    travel(2.minutes + ForecastLookup::RACE_CONDITION_TTL) do
      expect(short_lived.call("1 Infinite Loop, Cupertino, CA")).not_to be_cached
    end
  end

  it "caches geocoding results, normalising case and whitespace" do
    lookup.call("1 Infinite Loop, Cupertino, CA")
    lookup.call("  1 infinite loop,   CUPERTINO, ca ")

    expect(geocoder).to have_received(:locate).once
  end

  it "does not store raw addresses in cache keys" do
    lookup.call("1 Infinite Loop, Cupertino, CA")

    keys = cache.instance_variable_get(:@data).keys
    expect(keys).to all(satisfy { |key| !key.include?("Infinite") })
    expect(keys).to include("forecast/v1/us/95014")
  end

  context "when the address cannot be found" do
    let(:geocoder) { instance_double(Geocoding::NominatimClient, locate: nil) }

    it "raises AddressNotFound without calling the weather service" do
      expect { lookup.call("nowhere") }.to raise_error(ForecastLookup::AddressNotFound)
      expect(weather).not_to have_received(:fetch)
    end

    it "does not cache the miss" do
      2.times { lookup.call("nowhere") rescue ForecastLookup::AddressNotFound }

      expect(geocoder).to have_received(:locate).twice
    end
  end

  context "when the location has no postal code" do
    let(:geocoder) { instance_double(Geocoding::NominatimClient, locate: build_location(postal_code: nil, display_name: "California")) }

    it "raises PostalCodeNotFound" do
      expect { lookup.call("California") }.to raise_error(ForecastLookup::PostalCodeNotFound, /California/)
      expect(weather).not_to have_received(:fetch)
    end
  end

  context "when the weather service fails" do
    it "propagates the error and does not cache the failure" do
      allow(weather).to receive(:fetch).and_raise(ExternalApi::TimeoutError, "Open-Meteo timed out")

      expect { lookup.call("1 Infinite Loop, Cupertino, CA") }.to raise_error(ExternalApi::TimeoutError)

      allow(weather).to receive(:fetch).and_return(forecast)
      expect(lookup.call("1 Infinite Loop, Cupertino, CA")).not_to be_cached
    end
  end

  context "when the geocoder fails" do
    let(:geocoder) { instance_double(Geocoding::NominatimClient) }

    it "propagates the error" do
      allow(geocoder).to receive(:locate).and_raise(ExternalApi::RateLimitedError)

      expect { lookup.call("anywhere") }.to raise_error(ExternalApi::RateLimitedError)
    end
  end

  context "when the cache backend is down" do
    let(:cache) { ActiveSupport::Cache::NullStore.new }

    it "still serves live data" do
      expect(lookup.call("1 Infinite Loop, Cupertino, CA")).not_to be_cached
    end
  end
end
