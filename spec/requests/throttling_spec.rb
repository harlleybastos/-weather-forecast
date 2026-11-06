require "rails_helper"

RSpec.describe "Request throttling", type: :request do
  before do
    stub_nominatim
    stub_open_meteo
  end

  it "returns 429 once a client exceeds the per-minute lookup limit" do
    limit = Integer(ENV.fetch("FORECAST_THROTTLE_PER_MINUTE", 30))

    limit.times { get root_path, params: { address: "95014" } }
    expect(response).to have_http_status(:ok)

    get root_path, params: { address: "95014" }
    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers["retry-after"]).to eq("60")
    expect(response.body).to include("Too many requests")
  end

  it "does not throttle the landing page or health check" do
    40.times { get root_path }
    expect(response).to have_http_status(:ok)

    get rails_health_check_path
    expect(response).to have_http_status(:ok)
  end
end
