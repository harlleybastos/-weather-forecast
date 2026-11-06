module UpstreamStubs
  NOMINATIM_SEARCH = %r{\Ahttps://nominatim\.openstreetmap\.org/search}
  OPEN_METEO_FORECAST = %r{\Ahttps://api\.open-meteo\.com/v1/forecast}

  def fixture_json(name)
    file_fixture(name).read
  end

  def json_response(body, status: 200)
    { status: status, body: body, headers: { "Content-Type" => "application/json" } }
  end

  def stub_nominatim(body = fixture_json("nominatim_cupertino.json"), status: 200)
    stub_request(:get, NOMINATIM_SEARCH).to_return(json_response(body, status: status))
  end

  def stub_open_meteo(body = fixture_json("open_meteo_forecast.json"), status: 200)
    stub_request(:get, OPEN_METEO_FORECAST).to_return(json_response(body, status: status))
  end
end

RSpec.configure do |config|
  config.include UpstreamStubs
end
