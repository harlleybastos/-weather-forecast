# Weather Forecast

Rails app that looks up an address and shows the current temperature, today's
high and low, and a seven-day forecast. Results are cached by ZIP code for
30 minutes. The page labels each result as **Live** or **Cached**.

## Running

With Docker and the Compose plugin installed:

```sh
docker compose up --build
```

Open <http://localhost:3000>. Compose starts the app and Redis; use
`PORT=8080 docker compose up` if port 3000 is taken. The Compose defaults are
for local use: set your own `SECRET_KEY_BASE` and enable `FORCE_SSL` and
`ASSUME_SSL` when deploying behind a TLS proxy.

Without Docker, install Ruby 3.3.5, run `bundle install`, then
`bin/rails server`. Development uses an in-process cache unless `REDIS_URL`
is set, for example `redis://localhost:6379/0`. No database or API keys are
needed.

Search for `1 Infinite Loop, Cupertino, CA`, then repeat the search to see
the cache badge change. Addresses in the same ZIP code share a forecast.
The default search is US-only and temperatures are in Fahrenheit.

Settings live in [config/application.rb](config/application.rb).
`NOMINATIM_COUNTRY_CODES` accepts comma-separated country codes; an empty
value allows worldwide searches. `NOMINATIM_USER_AGENT` identifies the app
to the geocoder. `FORECAST_CACHE_TTL_SECONDS` and `GEOCODE_CACHE_TTL_SECONDS`
default to 1800 and 604800. Production uses Redis; its connection settings
are in [config/environments/production.rb](config/environments/production.rb).

## Checks

```sh
bundle exec rspec
bin/rubocop
bin/brakeman --no-pager
bundle exec bundle-audit check --update
```

RSpec blocks network access with WebMock and writes coverage to
`coverage/index.html`, with a 95% minimum line coverage requirement. Specs
cover upstream errors, postcode normalization, cache sharing and expiry,
rendered results, and throttling. CI runs these checks and a Docker smoke
test against `/up` and the landing page.

## Implementation notes

`ForecastsController` validates input through `AddressQuery` and calls
`ForecastLookup`. Nominatim resolves the address to a `Location`; Open-Meteo
provides the weather. The clients share `ExternalApi::JsonClient` for
timeouts, retries and error translation. The UI is server-rendered ERB.

Geocoded locations are cached for seven days, and forecasts for 30 minutes.
Address keys use a hash of the normalized input; forecast keys include the
country and normalized postal code. The forecast uses the coordinates of
the first address looked up in that ZIP. Upstream exceptions and unmatched
addresses aren't cached. Cached values are Ruby objects, so changes to their
shape need a bump to `ForecastLookup::CACHE_VERSION`.

Compose limits Redis to 128 MB with LRU eviction and persistence disabled.
Puma workers share this cache and the Rack::Attack counters. Lookups are
limited to 30 per minute per IP, configurable with
`FORECAST_THROTTLE_PER_MINUTE`. Redis errors are logged and treated as cache
misses, so an outage increases upstream traffic.

HTTP calls have a two-second connect timeout and five-second read timeout.
Connection failures and 502/503/504 responses get one retry; read timeouts
and 429 responses don't. Faraday wraps connect timeouts as connection
failures, so the client checks the underlying exception. Open-Meteo's local
timestamps need the response's UTC offset, and OSM postcodes need
normalization to handle ZIP+4 and lists of codes.

`race_condition_ttl` lets concurrent requests reuse an expired forecast
during refresh, but it doesn't prevent duplicate requests for a cold key.
For higher traffic, the next steps would be coordinating those first
fetches and replacing the public geocoder. The per-IP throttle doesn't
enforce an aggregate upstream request limit. Serving the last known
forecast during upstream outages would also improve availability.
