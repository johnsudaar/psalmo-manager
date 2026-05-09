module Actors
  class UpdateRegistrationOverride
    include Interactor

    ALLOWED_FIELDS = %w[excluded_from_stats is_unaccompanied_minor responsible_person_note].freeze
    BOOLEAN_FIELDS = %w[excluded_from_stats is_unaccompanied_minor].freeze

    def call
      registration = context.registration
      field        = context.field.to_s
      value        = context.value

      unless ALLOWED_FIELDS.include?(field)
        context.fail!(error: "Champ non autorisé")
      end

      value = cast_boolean(value) if BOOLEAN_FIELDS.include?(field)

      unless registration.update(field => value)
        context.fail!(error: registration.errors.full_messages.join(", "))
      end
    end

    private

    def cast_boolean(value)
      %w[true 1].include?(value.to_s)
    end
  end
end
