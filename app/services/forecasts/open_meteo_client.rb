module Forecasts
  # API documentation: https://open-meteo.com/en/docs
  class OpenMeteoClient
    FORECAST_DAYS = 7
    CURRENT_FIELDS = %w[temperature_2m apparent_temperature relative_humidity_2m wind_speed_10m weather_code].freeze
    DAILY_FIELDS = %w[weather_code temperature_2m_max temperature_2m_min precipitation_probability_max].freeze
    # Open-Meteo labels this "mp/h"; show the conventional spelling instead.
    WIND_SPEED_UNIT = "mph"

    def initialize(http: nil)
      @http = http || ExternalApi::JsonClient.new(
        service: "Open-Meteo",
        base_url: Rails.configuration.x.open_meteo.base_url
      )
    end

    def fetch(latitude:, longitude:)
      payload = http.get("/v1/forecast", {
        latitude: latitude,
        longitude: longitude,
        current: CURRENT_FIELDS.join(","),
        daily: DAILY_FIELDS.join(","),
        temperature_unit: "fahrenheit",
        wind_speed_unit: WIND_SPEED_UNIT,
        timezone: "auto",
        forecast_days: FORECAST_DAYS
      })

      build_forecast(payload)
    end

    private

    attr_reader :http

    def build_forecast(payload)
      current = payload.fetch("current")
      units = payload.fetch("current_units")

      Forecast.new(
        temperature: Float(current.fetch("temperature_2m")),
        feels_like: optional_float(current["apparent_temperature"]),
        humidity: optional_float(current["relative_humidity_2m"]),
        wind_speed: optional_float(current["wind_speed_10m"]),
        weather_code: current["weather_code"],
        observed_at: DateTime.iso8601("#{current.fetch("time")}#{utc_offset(payload)}").to_time,
        temperature_unit: units.fetch("temperature_2m"),
        wind_speed_unit: WIND_SPEED_UNIT,
        days: build_days(payload.fetch("daily"))
      )
    rescue KeyError, TypeError, ArgumentError, NoMethodError => e
      raise ExternalApi::InvalidResponseError, "Open-Meteo returned a malformed forecast (#{e.class})"
    end

    def build_days(daily)
      daily.fetch("time").each_with_index.map do |date, i|
        Forecast::Day.new(
          date: Date.iso8601(date),
          high: Float(daily.fetch("temperature_2m_max")[i]),
          low: Float(daily.fetch("temperature_2m_min")[i]),
          weather_code: daily["weather_code"]&.at(i),
          precipitation_probability: daily["precipitation_probability_max"]&.at(i)
        )
      end
    end

    def optional_float(value)
      value.nil? ? nil : Float(value)
    end

    # Open-Meteo returns local times without an offset; attach it so the
    # timestamp is unambiguous.
    def utc_offset(payload)
      ActiveSupport::TimeZone.seconds_to_utc_offset(payload.fetch("utc_offset_seconds", 0).to_i)
    end
  end
end
