module Actors
  class RemoveWorkshopOverride
    include Interactor

    def call
      registration = context.registration

      RegistrationWorkshop.transaction do
        registration.registration_workshops.destroy_all

        restored_rows.each do |row|
          registration.registration_workshops.create!(
            workshop_id: row.fetch("workshop_id"),
            price_paid_cents: row.fetch("price_paid_cents", 0),
            is_override: false
          )
        end

        registration.update!(
          has_workshop_override: false,
          workshop_override_backup: []
        )
        registration.detect_conflict!
      end
    end

    private

    def restored_rows
      Array(context.registration.workshop_override_backup)
    end
  end
end
