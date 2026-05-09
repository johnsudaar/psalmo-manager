module Actors
  class CreateEdition
    include Interactor

    def call
      edition_params = context.edition_params.to_h
      logo = edition_params.delete("logo")

      if edition_params["km_rate_cents"].present?
        edition_params["km_rate_cents"] = (edition_params["km_rate_cents"].to_s.gsub(/[€\s]/, "").gsub(",", ".").to_f * 100).round
      end

      edition = Edition.new(edition_params)
      edition.logo.attach(logo) if logo.present?

      unless edition.save
        context.fail!(error: edition.errors.full_messages.join(", "))
      end

      context.edition = edition
    end
  end
end
