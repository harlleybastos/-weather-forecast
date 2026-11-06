require "rails_helper"

RSpec.describe Forecasts::OpenMeteoClient do
  subject(:client) { described_class.new }

  let(:payload) { JSON.parse(fixture_json("open_meteo_forecast.json")) }

  it "returns current conditions and a 7-day outlook" do
    stub_open_meteo

    forecast = client.fetch(latitude: 37.33, longitude: -122.03)

    expect(forecast).to have_attributes(
      temperature: 72.8,
      feels_like: 68.4,
      humidity: 32.0,
      wind_speed: 6.0,
      weather_code: 1,
      condition: "Mainly clear",
      temperature_unit: "°F",
      wind_speed_unit: "mph",
      observed_at: Time.utc(2026, 11, 6, 21, 0)
    )
    expect(forecast.days.size).to eq(7)
    expect(forecast.today).to have_attributes(date: Date.new(2026, 11, 6), high: 73.7, low: 44.1, condition: "Overcast", precipitation_probability: 0)
  end

  it "requests Fahrenheit, mph and the local timezone for the given coordinates" do
    stub = stub_open_meteo.with(query: hash_including(
      "latitude" => "37.33", "longitude" => "-122.03",
      "temperature_unit" => "fahrenheit", "wind_speed_unit" => "mph", "timezone" => "auto", "forecast_days" => "7"
    ))

    client.fetch(latitude: 37.33, longitude: -122.03)

    expect(stub).to have_been_requested
  end

  it "tolerates missing optional fields" do
    payload["current"].except!("apparent_temperature", "relative_humidity_2m", "wind_speed_10m")
    payload["daily"].except!("weather_code", "precipitation_probability_max")
    stub_open_meteo(payload.to_json)

    forecast = client.fetch(latitude: 1, longitude: 2)

    expect(forecast).to have_attributes(feels_like: nil, humidity: nil, wind_speed: nil)
    expect(forecast.today).to have_attributes(weather_code: nil, precipitation_probability: nil, condition: "Unknown")
  end

  describe "malformed responses" do
    it "raises InvalidResponseError when the current block is missing" do
      stub_open_meteo(payload.except("current").to_json)

      expect { client.fetch(latitude: 1, longitude: 2) }.to raise_error(ExternalApi::InvalidResponseError, /Open-Meteo/)
    end

    it "raises InvalidResponseError when the current temperature is null" do
      payload["current"]["temperature_2m"] = nil
      stub_open_meteo(payload.to_json)

      expect { client.fetch(latitude: 1, longitude: 2) }.to raise_error(ExternalApi::InvalidResponseError)
    end

    it "raises InvalidResponseError when a timestamp cannot be parsed" do
      payload["current"]["time"] = "yesterday-ish"
      stub_open_meteo(payload.to_json)

      expect { client.fetch(latitude: 1, longitude: 2) }.to raise_error(ExternalApi::InvalidResponseError)
    end

    it "raises InvalidResponseError when the payload is not an object" do
      stub_open_meteo("[1, 2, 3]")

      expect { client.fetch(latitude: 1, longitude: 2) }.to raise_error(ExternalApi::InvalidResponseError)
    end
  end

  it "surfaces Open-Meteo's 400 for invalid coordinates as an UpstreamError" do
    stub_open_meteo('{"error":true,"reason":"Latitude must be in range of -90 to 90°."}', status: 400)

    expect { client.fetch(latitude: 999, longitude: 0) }.to raise_error(ExternalApi::UpstreamError) { |error|
      expect(error.status).to eq(400)
    }
  end
end
