require "rails_helper"

RSpec.describe "Forecasts", type: :request do
  let(:address) { "1 Infinite Loop, Cupertino, CA" }

  def page
    Nokogiri::HTML(response.body)
  end

  def text_at(test_id)
    page.at_css("[data-testid='#{test_id}']")&.text&.squish
  end

  describe "GET / without an address" do
    it "renders the search form without calling upstream" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(page.at_css("input[name='address']")).to be_present
      expect(page.at_css(".card")).to be_nil
    end
  end

  describe "GET / with an address" do
    before do
      stub_nominatim
      stub_open_meteo
    end

    it "renders the current temperature, high/low and extended forecast" do
      get root_path, params: { address: address }

      expect(response).to have_http_status(:ok)
      expect(text_at("current-temperature")).to eq("73°F")
      expect(text_at("today-high")).to eq("74°F")
      expect(text_at("today-low")).to eq("44°F")
      expect(page.css("table.daily tbody tr").size).to eq(7)
      expect(response.body).to include("ZIP 95014", "Mainly clear")
    end

    it "marks the first response as live and later ones as cached" do
      get root_path, params: { address: address }
      expect(page.at_css(".badge").text).to eq("Live")
      expect(text_at("cache-status")).to eq("Fetched live from the weather service")

      travel 10.minutes do
        get root_path, params: { address: address }
      end
      expect(page.at_css(".badge").text).to eq("Cached")
      expect(text_at("cache-status")).to eq("Served from cache · fetched 10 minutes ago")

      expect(a_request(:get, UpstreamStubs::OPEN_METEO_FORECAST)).to have_been_made.once
    end

    it "preserves the submitted address in the form" do
      get root_path, params: { address: address }

      expect(page.at_css("input[name='address']")["value"]).to eq(address)
    end

    it "escapes user input" do
      get root_path, params: { address: "<script>alert(1)</script>" }

      expect(response.body).not_to include("<script>alert(1)</script>")
    end
  end

  describe "validation errors" do
    it "rejects a blank address without calling upstream" do
      get root_path, params: { address: "   " }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(page.at_css(".alert").text).to include("Address can't be blank")
      expect(a_request(:get, UpstreamStubs::NOMINATIM_SEARCH)).not_to have_been_made
    end

    it "rejects an overly long address" do
      get root_path, params: { address: "a" * 201 }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(page.at_css(".alert").text).to include("too long")
    end
  end

  describe "lookup failures" do
    it "reports an unknown address" do
      stub_nominatim("[]")

      get root_path, params: { address: "zzzz not a place" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(page.at_css(".alert").text).to include("couldn't find that address")
    end

    it "reports an address without a ZIP code" do
      stub_nominatim(fixture_json("nominatim_no_postcode.json"))

      get root_path, params: { address: "California" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(page.at_css(".alert").text).to include("doesn't have a ZIP code")
    end
  end

  describe "upstream failures" do
    shared_examples "a degraded response" do |message|
      it "renders a friendly error with 503 and logs the cause" do
        allow(Rails.logger).to receive(:warn).and_call_original

        get root_path, params: { address: address }

        expect(response).to have_http_status(:service_unavailable)
        expect(page.at_css(".alert").text).to include(message)
        expect(page.at_css(".card")).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/\[forecast\] ExternalApi::/)
      end
    end

    context "when the geocoder times out" do
      before { stub_request(:get, UpstreamStubs::NOMINATIM_SEARCH).to_timeout }

      it_behaves_like "a degraded response", "temporarily unavailable"
    end

    context "when DNS resolution fails" do
      before { stub_request(:get, UpstreamStubs::NOMINATIM_SEARCH).to_raise(SocketError) }

      it_behaves_like "a degraded response", "temporarily unavailable"
    end

    context "when the geocoder rate-limits us" do
      before { stub_nominatim("", status: 429) }

      it_behaves_like "a degraded response", "too many requests"
    end

    context "when the weather service returns 5xx" do
      before do
        stub_nominatim
        stub_open_meteo("Bad Gateway", status: 502)
      end

      it_behaves_like "a degraded response", "temporarily unavailable"
    end

    context "when the weather service returns a non-parseable body" do
      before do
        stub_nominatim
        stub_open_meteo("<html>oops</html>")
      end

      it_behaves_like "a degraded response", "temporarily unavailable"
    end

    context "when the weather service times out" do
      before do
        stub_nominatim
        stub_request(:get, UpstreamStubs::OPEN_METEO_FORECAST).to_timeout
      end

      it_behaves_like "a degraded response", "temporarily unavailable"
    end

    it "recovers on the next request because failures are not cached" do
      stub_nominatim
      stub_open_meteo("", status: 500)
      get root_path, params: { address: address }
      expect(response).to have_http_status(:service_unavailable)

      stub_open_meteo
      get root_path, params: { address: address }
      expect(response).to have_http_status(:ok)
      expect(page.at_css(".badge").text).to eq("Live")
    end
  end
end
