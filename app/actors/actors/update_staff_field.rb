module Actors
  class UpdateStaffField
    include Interactor

    ALLOWED_FIELDS = %w[
      allowance_cents allowance_label km_traveled km_rate_override_cents transport_mode
      travel_override_cents
      supplies_cost_cents accommodation_cost_cents meals_cost_cents tickets_cost_cents
      member_uncovered_accommodation_cents member_uncovered_meals_cents
      member_uncovered_tickets_cents member_covered_tickets_cents notes
    ].freeze

    CENTS_FIELDS = %w[
      allowance_cents km_rate_override_cents travel_override_cents supplies_cost_cents accommodation_cost_cents
      meals_cost_cents tickets_cost_cents member_uncovered_accommodation_cents
      member_uncovered_meals_cents member_uncovered_tickets_cents member_covered_tickets_cents
    ].freeze

    def call
      staff_profile = context.staff_profile
      field         = context.field.to_s
      value         = context.value

      unless ALLOWED_FIELDS.include?(field)
        context.fail!(error: "Champ non autorisé")
      end

      if field == "km_rate_override_cents" && value.to_s.strip.empty?
        value = nil
      elsif CENTS_FIELDS.include?(field)
        value = (value.to_s.gsub(/[€\s]/, "").gsub(",", ".").to_f * 100).round
      end

      unless staff_profile.update(field => value)
        context.fail!(error: staff_profile.errors.full_messages.join(", "))
      end
    end
  end
end
