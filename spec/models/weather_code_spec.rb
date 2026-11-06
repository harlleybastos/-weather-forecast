require "rails_helper"

RSpec.describe WeatherCode do
  it "describes known WMO codes" do
    expect(described_class.describe(0)).to eq("Clear sky")
    expect(described_class.describe(95)).to eq("Thunderstorm")
  end

  it "falls back for unknown or missing codes" do
    expect(described_class.describe(1234)).to eq("Unknown")
    expect(described_class.describe(nil)).to eq("Unknown")
  end
end
