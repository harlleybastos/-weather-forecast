module ExternalApi
  # Translates HTTP failures into ExternalApi errors, preserving Exception#cause.
  class JsonClient
    RETRYABLE_STATUSES = [ 502, 503, 504 ].freeze

    attr_reader :service

    def initialize(service:, base_url:, headers: {}, http_config: Rails.configuration.x.http)
      @service = service
      @base_url = base_url
      @headers = headers
      @http_config = http_config
    end

    def get(path, params = {})
      response = connection.get(path, params)
      handle_response(response)
    rescue Faraday::TimeoutError
      raise TimeoutError, "#{service} timed out"
    rescue Faraday::ConnectionFailed => e
      # Faraday reports connect-phase timeouts as ConnectionFailed.
      raise TimeoutError, "#{service} timed out while connecting" if e.wrapped_exception.is_a?(Net::OpenTimeout)

      raise ConnectionError, "#{service} is unreachable"
    rescue Faraday::SSLError
      raise ConnectionError, "#{service} TLS handshake failed"
    end

    private

    attr_reader :base_url, :headers, :http_config

    def handle_response(response)
      case response.status
      when 200..299 then parse(response.body)
      when 429 then raise RateLimitedError, "#{service} rate limit exceeded"
      else raise UpstreamError.new("#{service} responded with HTTP #{response.status}", status: response.status)
      end
    end

    def parse(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      raise InvalidResponseError, "#{service} returned a non-JSON body"
    end

    def connection
      @connection ||= Faraday.new(url: base_url, headers: default_headers.merge(headers)) do |f|
        f.options.open_timeout = http_config.open_timeout
        f.options.timeout = http_config.read_timeout
        # Retry connection failures and temporary server errors once. Read
        # timeouts and 429s are not retried to avoid adding load upstream.
        f.request :retry,
          max: 1,
          interval: http_config.retry_interval,
          methods: %i[get],
          retry_statuses: RETRYABLE_STATUSES,
          exceptions: [ Faraday::ConnectionFailed, Faraday::RetriableResponse ]
        f.adapter Faraday.default_adapter
      end
    end

    def default_headers
      { "Accept" => "application/json" }
    end
  end
end
