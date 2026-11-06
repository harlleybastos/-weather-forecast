require "rails_helper"

RSpec.describe ExternalApi::JsonClient do
  subject(:client) { described_class.new(service: "Example", base_url: "https://api.example.com", headers: { "User-Agent" => "spec" }) }

  let(:url) { "https://api.example.com/items?id=1" }

  it "returns the parsed JSON body and sends the configured headers" do
    stub_request(:get, url)
      .with(headers: { "Accept" => "application/json", "User-Agent" => "spec" })
      .to_return(status: 200, body: '{"ok":true}')

    expect(client.get("/items", id: 1)).to eq("ok" => true)
  end

  it "applies the configured open and read timeouts" do
    connection = client.send(:connection)

    expect(connection.options.open_timeout).to eq(Rails.configuration.x.http.open_timeout)
    expect(connection.options.timeout).to eq(Rails.configuration.x.http.read_timeout)
  end

  context "when the connection cannot be opened in time" do
    it "retries once (nothing was sent yet), then raises TimeoutError" do
      stub = stub_request(:get, url).to_timeout

      expect { client.get("/items", id: 1) }.to raise_error(ExternalApi::TimeoutError, /timed out while connecting/)
      expect(stub).to have_been_requested.twice
    end
  end

  context "when the response is not read in time" do
    it "raises TimeoutError without retrying" do
      stub = stub_request(:get, url).to_raise(Net::ReadTimeout)

      expect { client.get("/items", id: 1) }.to raise_error(ExternalApi::TimeoutError, /Example timed out/)
      expect(stub).to have_been_requested.once
    end
  end

  context "when DNS resolution fails" do
    it "retries once, then raises ConnectionError preserving the cause" do
      stub = stub_request(:get, url).to_raise(SocketError.new("getaddrinfo: Name or service not known"))

      expect { client.get("/items", id: 1) }.to raise_error(ExternalApi::ConnectionError) { |error|
        expect(error.cause).to be_a(Faraday::ConnectionFailed)
      }
      expect(stub).to have_been_requested.twice
    end
  end

  context "when the connection is refused" do
    it "raises ConnectionError" do
      stub_request(:get, url).to_raise(Errno::ECONNREFUSED)

      expect { client.get("/items", id: 1) }.to raise_error(ExternalApi::ConnectionError)
    end
  end

  context "when rate limited" do
    it "raises RateLimitedError without retrying" do
      stub = stub_request(:get, url).to_return(status: 429, body: "")

      expect { client.get("/items", id: 1) }.to raise_error(ExternalApi::RateLimitedError)
      expect(stub).to have_been_requested.once
    end
  end

  context "when the upstream returns a 5xx" do
    it "retries a transient 503 once and succeeds if the retry does" do
      stub_request(:get, url).to_return({ status: 503 }, { status: 200, body: "[]" })

      expect(client.get("/items", id: 1)).to eq([])
    end

    it "raises UpstreamError with the status when the retry also fails" do
      stub = stub_request(:get, url).to_return(status: 503, body: "Service Unavailable")

      expect { client.get("/items", id: 1) }.to raise_error(ExternalApi::UpstreamError) { |error|
        expect(error.status).to eq(503)
      }
      expect(stub).to have_been_requested.twice
    end

    it "does not retry a 500, which is unlikely to be transient" do
      stub = stub_request(:get, url).to_return(status: 500)

      expect { client.get("/items", id: 1) }.to raise_error(ExternalApi::UpstreamError, /HTTP 500/)
      expect(stub).to have_been_requested.once
    end
  end

  context "when the upstream returns a 4xx" do
    it "raises UpstreamError" do
      stub_request(:get, url).to_return(status: 400, body: '{"error":true}')

      expect { client.get("/items", id: 1) }.to raise_error(ExternalApi::UpstreamError) { |error|
        expect(error.status).to eq(400)
      }
    end
  end

  context "when the body is not JSON" do
    it "raises InvalidResponseError" do
      stub_request(:get, url).to_return(status: 200, body: "<html>Gateway</html>")

      expect { client.get("/items", id: 1) }.to raise_error(ExternalApi::InvalidResponseError)
    end

    it "raises InvalidResponseError for an empty body" do
      stub_request(:get, url).to_return(status: 200, body: "")

      expect { client.get("/items", id: 1) }.to raise_error(ExternalApi::InvalidResponseError)
    end
  end

  context "when TLS negotiation fails" do
    it "raises ConnectionError" do
      stub_request(:get, url).to_raise(OpenSSL::SSL::SSLError)

      expect { client.get("/items", id: 1) }.to raise_error(ExternalApi::ConnectionError)
    end
  end
end
