module Webhooks
  class HelloassoController < ActionController::API
    def create
      return head :unauthorized unless valid_signature?

      payload = JSON.parse(request.body.read)
      Helloasso::WebhookProcessor.new(payload).call
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def valid_signature?
      secret = ENV["HELLOASSO_WEBHOOK_SECRET"]
      return false if secret.blank?

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, request.raw_post)
      ActiveSupport::SecurityUtils.secure_compare(
        expected,
        request.headers["X-HelloAsso-Signature"].to_s
      )
    end
  end
end
