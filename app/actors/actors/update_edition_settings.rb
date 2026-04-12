module Actors
  class UpdateEditionSettings
    include Interactor

    ALLOWED_FIELDS = %w[
      name start_date end_date km_rate_cents helloasso_form_slug helloasso_form_type
    ].freeze

    def call
      edition = context.edition
      field   = context.field.to_s
      value   = context.value

      unless ALLOWED_FIELDS.include?(field)
        context.fail!(error: "Champ non autorisé")
      end

      if field == "km_rate_cents"
        value = (value.to_s.gsub(/[€\s]/, "").gsub(",", ".").to_f * 100).round
      end

      unless edition.update(field => value)
        context.fail!(error: edition.errors.full_messages.join(", "))
      end
    end
  end
end
