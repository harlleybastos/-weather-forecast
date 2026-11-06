require "rails_helper"

RSpec.describe Geocoding::NominatimClient do
  subject(:client) { described_class.new }

  def nominatim_result(address:, lat: "37.33", lon: "-122.03", display_name: "Somewhere")
    [ { "lat" => lat, "lon" => lon, "display_name" => display_name, "address" => address } ].to_json
  end

  it "returns a Location for a matching address" do
    stub_nominatim

    location = client.locate("1 Infinite Loop, Cupertino, CA")

    expect(location).to have_attributes(
      postal_code: "95014",
      country_code: "us",
      latitude: 37.3316697,
      longitude: -122.0300982,
      display_name: a_string_including("Cupertino")
    )
  end

  it "sends the address, US country filter and identifying User-Agent" do
    stub = stub_nominatim.with(
      query: hash_including("q" => "1 Infinite Loop", "countrycodes" => "us", "addressdetails" => "1", "limit" => "1"),
      headers: { "User-Agent" => Rails.configuration.x.nominatim.user_agent }
    )

    client.locate("1 Infinite Loop")

    expect(stub).to have_been_requested
  end

  it "searches worldwide when no country filter is configured" do
    stub = stub_nominatim.with { |request| !request.uri.query_values.key?("countrycodes") }

    described_class.new(country_codes: "").locate("Berlin")

    expect(stub).to have_been_requested
  end

  it "returns nil when nothing matches" do
    stub_nominatim("[]")

    expect(client.locate("nowhere at all")).to be_nil
  end

  it "returns a Location without a postal code for broad areas" do
    stub_nominatim(fixture_json("nominatim_no_postcode.json"))

    location = client.locate("California")

    expect(location.postal_code).to be_nil
    expect(location).not_to be_postal_code
  end

  describe "postal code normalization" do
    {
      "95014-2083" => "95014",
      "95014;95015" => "95014",
      " 95014 " => "95014",
      "CA" => nil
    }.each do |raw, expected|
      it "normalizes US postcode #{raw.inspect} to #{expected.inspect}" do
        stub_nominatim(nominatim_result(address: { "postcode" => raw, "country_code" => "us" }))

        expect(client.locate("x").postal_code).to eq(expected)
      end
    end

    it "keeps non-US postcodes, upcased" do
      stub_nominatim(nominatim_result(address: { "postcode" => "sw1a 1aa", "country_code" => "GB" }))

      expect(client.locate("x")).to have_attributes(postal_code: "SW1A 1AA", country_code: "gb")
    end
  end

  describe "malformed responses" do
    it "raises InvalidResponseError when the payload is not a list" do
      stub_nominatim('{"error":"Unable to geocode"}')

      expect { client.locate("x") }.to raise_error(ExternalApi::InvalidResponseError)
    end

    it "raises InvalidResponseError when coordinates are missing" do
      stub_nominatim([ { "display_name" => "x", "address" => { "country_code" => "us" } } ].to_json)

      expect { client.locate("x") }.to raise_error(ExternalApi::InvalidResponseError)
    end

    it "raises InvalidResponseError when coordinates are not numeric" do
      stub_nominatim(nominatim_result(lat: "north", address: { "country_code" => "us" }))

      expect { client.locate("x") }.to raise_error(ExternalApi::InvalidResponseError)
    end
  end

  it "propagates upstream failures as ExternalApi errors" do
    stub_request(:get, UpstreamStubs::NOMINATIM_SEARCH).to_timeout

    expect { client.locate("x") }.to raise_error(ExternalApi::TimeoutError, /Nominatim/)
  end
end
