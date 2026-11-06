module ExternalApi
  class Error < StandardError; end

  class TimeoutError < Error; end

  class ConnectionError < Error; end

  # The upstream answered 429 Too Many Requests.
  class RateLimitedError < Error; end

  # The upstream answered with a non-success status (typically 5xx).
  class UpstreamError < Error
    attr_reader :status

    def initialize(message = nil, status: nil)
      super(message)
      @status = status
    end
  end

  # The upstream answered 2xx but the body was not what we expected.
  class InvalidResponseError < Error; end
end
