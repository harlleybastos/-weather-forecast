module Geocoding
  # Usage policy: https://operations.osmfoundation.org/policies/nominatim/
  class NominatimClient
    US_ZIP = /\A\d{5}/

    def initialize(http: nil, country_codes: Rails.configuration.x.nominatim.country_codes)
      @country_codes = country_codes.presence
      @http = http || ExternalApi::JsonClient.new(
        service: "Nominatim",
        base_url: Rails.configuration.x.nominatim.base_url,
        headers: { "User-Agent" => Rails.configuration.x.nominatim.user_agent }
      )
    end

    # Returns a Location, or nil when the address matches nothing.
    def locate(address)
      params = { q: address, format: "jsonv2", addressdetails: 1, limit: 1, countrycodes: country_codes }.compact
      results = http.get("/search", params)
      raise ExternalApi::InvalidResponseError, "Nominatim returned an unexpected payload" unless results.is_a?(Array)

      results.first&.then { |result| build_location(result) }
    end

    private

    attr_reader :http, :country_codes

    def build_location(result)
      details = result.fetch("address")
      country_code = details.fetch("country_code").downcase

      Location.new(
        display_name: result.fetch("display_name"),
        postal_code: normalize_postal_code(details["postcode"], country_code),
        country_code: country_code,
        latitude: Float(result.fetch("lat")),
        longitude: Float(result.fetch("lon"))
      )
    rescue KeyError, TypeError, ArgumentError, NoMethodError => e
      raise ExternalApi::InvalidResponseError, "Nominatim returned a malformed result (#{e.class})"
    end

    # OSM postcodes are user-entered: they can be lists ("95014;95015"),
    # ZIP+4 ("95014-2083") or oddly spaced. Reduce them to one canonical code
    # so that the same area always maps to the same cache entry.
    def normalize_postal_code(raw, country_code)
      code = raw.to_s.split(/[;,]/).first.to_s.strip.upcase
      code = code[US_ZIP].to_s if country_code == "us"
      code.presence
    end
  end
end
