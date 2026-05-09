require "rails_helper"

RSpec.describe Helloasso::Client do
  subject(:client) { described_class.new }

  let(:token_response) do
    { access_token: "fake-token", token_type: "Bearer", expires_in: 1800 }.to_json
  end

  around do |example|
    # Use a real MemoryStore so token caching is testable
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = original_cache
  end

  before do
    Rails.cache.delete(described_class::CACHE_KEY)

    stub_request(:post, "https://api.helloasso.com/oauth2/token")
      .to_return(
        status: 200,
        body: token_response,
        headers: { "Content-Type" => "application/json" }
      )
  end

  describe "#get" do
    it "fetches an OAuth2 token and includes it as a Bearer header" do
      api_stub = stub_request(:get, %r{api\.helloasso\.com/v5})
                   .with(headers: { "Authorization" => "Bearer fake-token" })
                   .to_return(
                     status: 200,
                     body: "{}",
                     headers: { "Content-Type" => "application/json" }
                   )

      client.get("/v5/organizations/psalmodia/forms")

      expect(api_stub).to have_been_requested
    end

    it "caches the token so only one token request is made for two API calls" do
      stub_request(:get, %r{api\.helloasso\.com/v5})
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      client.get("/v5/anything")
      client.get("/v5/other")

      expect(WebMock).to have_requested(:post, "https://api.helloasso.com/oauth2/token").once
    end

    it "raises Faraday::Error on non-2xx responses" do
      stub_request(:get, %r{api\.helloasso\.com/v5})
        .to_return(status: 500, body: "Internal Server Error")

      expect { client.get("/v5/bad") }.to raise_error(Faraday::Error)
    end
  end
end
