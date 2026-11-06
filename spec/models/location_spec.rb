require "rails_helper"

RSpec.describe Location do
  let(:location) { described_class.new(display_name: "x", postal_code: "95014", country_code: "us", latitude: 1.0, longitude: 2.0) }

  it "builds a country-scoped postal code key" do
    expect(location.postal_code_key).to eq("us/95014")
  end

  it "reports whether a postal code is present" do
    expect(location).to be_postal_code
    expect(location.with(postal_code: nil)).not_to be_postal_code
  end
end
