module Helloasso
  class Client
    BASE_URL  = "https://api.helloasso.com/v5"
    TOKEN_URL = "https://api.helloasso.com/oauth2/token"
    CACHE_KEY = "helloasso_access_token"
    TOKEN_TTL = 25.minutes

    def initialize
      @conn = Faraday.new(BASE_URL) do |f|
        f.request :json
        f.response :json
        f.response :raise_error
        f.request :retry, max: 3, interval: 1, backoff_factor: 2,
                           exceptions: [ Faraday::TimeoutError, Faraday::ServerError ]
      end
    end

    def get(path, params = {})
      @conn.get(path, params) { |req| req.headers["Authorization"] = "Bearer #{access_token}" }
    end

    private

    def access_token
      Rails.cache.fetch(CACHE_KEY, expires_in: TOKEN_TTL) { fetch_token }
    end

    def fetch_token
      resp = Faraday.post(TOKEN_URL, {
        grant_type: "client_credentials",
        client_id: ENV["HELLOASSO_CLIENT_ID"],
        client_secret: ENV["HELLOASSO_CLIENT_SECRET"]
      })
      JSON.parse(resp.body)["access_token"]
    end
  end
end
