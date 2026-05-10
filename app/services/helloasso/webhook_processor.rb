module Helloasso
  class WebhookProcessor
    def initialize(payload)
      @payload = payload
    end

    def call
      case @payload["eventType"]
      when "Order"
        edition = find_edition_from_form(@payload.dig("data", "form", "formSlug"))
        return unless edition

        SyncService.new(edition).process_order(@payload.dig("data", "order"))
      when "Payment"
        # Payment state changes (e.g. refunds) — not yet consumed; log for future use
        Rails.logger.info("[Helloasso::WebhookProcessor] Payment event received (not processed)")
      end
    end

    private

    def find_edition_from_form(slug)
      Edition.find_by(helloasso_form_slug: slug)
    end
  end
end
