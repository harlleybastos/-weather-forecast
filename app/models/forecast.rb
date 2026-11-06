class Forecast < Data.define(
  :temperature, :feels_like, :humidity, :wind_speed, :weather_code,
  :observed_at, :temperature_unit, :wind_speed_unit, :days
)
  Day = Data.define(:date, :high, :low, :weather_code, :precipitation_probability) do
    def condition
      WeatherCode.describe(weather_code)
    end
  end

  def condition
    WeatherCode.describe(weather_code)
  end

  def today
    days.first
  end
end
