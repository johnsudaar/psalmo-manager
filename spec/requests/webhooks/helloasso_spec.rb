require "rails_helper"

RSpec.describe "Webhooks::Helloasso", type: :request do
  let(:webhook_secret) { "test-webhook-secret" }
  let(:payload) do
    { eventType: "Order", data: { order: {}, form: { formSlug: "psalmodia-2026" } } }.to_json
  end
  let(:valid_signature) do
    OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, payload)
  end

  around do |example|
    original = ENV["HELLOASSO_WEBHOOK_SECRET"]
    ENV["HELLOASSO_WEBHOOK_SECRET"] = webhook_secret
    example.run
    ENV["HELLOASSO_WEBHOOK_SECRET"] = original
  end

  before do
    # Prevent WebhookProcessor from calling SyncService in these request specs
    allow(Helloasso::WebhookProcessor).to receive(:new).and_return(
      instance_double(Helloasso::WebhookProcessor, call: nil)
    )
  end

  describe "POST /webhooks/helloasso" do
    context "with a valid signature" do
      it "returns 200 OK" do
        post "/webhooks/helloasso",
             params: payload,
             headers: {
               "Content-Type"          => "application/json",
               "X-HelloAsso-Signature" => valid_signature
             }
        expect(response).to have_http_status(:ok)
      end
    end

    context "with an invalid signature" do
      it "returns 401 Unauthorized" do
        post "/webhooks/helloasso",
             params: payload,
             headers: {
               "Content-Type"          => "application/json",
               "X-HelloAsso-Signature" => "invalidsignature"
             }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a missing signature header" do
      it "returns 401 Unauthorized" do
        post "/webhooks/helloasso",
             params: payload,
             headers: { "Content-Type" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with malformed JSON" do
      it "returns 400 Bad Request" do
        post "/webhooks/helloasso",
             params: "not-json",
             headers: {
               "Content-Type"          => "application/json",
               "X-HelloAsso-Signature" => OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, "not-json")
             }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
