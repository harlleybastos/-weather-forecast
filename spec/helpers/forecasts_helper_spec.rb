require "rails_helper"

RSpec.describe ForecastsHelper, type: :helper do
  describe "#format_temperature" do
    it "rounds and appends the unit" do
      expect(helper.format_temperature(72.6, "°F")).to eq("73°F")
    end

    it "renders a placeholder for missing values" do
      expect(helper.format_temperature(nil, "°F")).to eq("—")
    end
  end

  describe "#cache_badge" do
    let(:result) { ForecastLookup::Result.new(location: nil, forecast: nil, cached: cached, fetched_at: 5.minutes.ago) }

    context "when cached" do
      let(:cached) { true }

      it { expect(helper.cache_badge(result)).to include("Cached", "badge--cached", "5 minutes") }
    end

    context "when live" do
      let(:cached) { false }

      it { expect(helper.cache_badge(result)).to include("Live", "badge--live") }
    end
  end
end
