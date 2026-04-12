module Actors
  class ApplyWorkshopSubstitution
    include Interactor

    def call
      registration = context.registration
      workshop_ids = Array(context.workshop_ids).reject(&:blank?).map(&:to_i).uniq

      workshops = Workshop.where(id: workshop_ids, edition_id: registration.edition_id).order(:time_slot, :name)

      if workshops.size != workshop_ids.size
        context.fail!(error: "Atelier hors édition")
      end

      if workshops.size > 2
        context.fail!(error: "Une inscription ne peut pas avoir plus de 2 ateliers")
      end

      time_slots = workshops.map(&:time_slot)
      if time_slots.uniq.size != time_slots.size
        context.fail!(error: "Une inscription ne peut pas avoir deux ateliers sur le même créneau")
      end

      if time_slots.include?("journee") && workshops.size > 1
        context.fail!(error: "Un atelier journée ne peut pas être combiné avec un autre atelier")
      end

      RegistrationWorkshop.transaction do
        backup_rows = if registration.has_workshop_override?
          registration.workshop_override_backup
        else
          registration.registration_workshops.order(:id).map do |rw|
            {
              workshop_id: rw.workshop_id,
              price_paid_cents: rw.price_paid_cents
            }
          end
        end

        registration.registration_workshops.destroy_all

        registration_workshops = workshops.map do |workshop|
          rw = registration.registration_workshops.build(
            workshop: workshop,
            price_paid_cents: 0,
            is_override: true
          )

          unless rw.save
            context.fail!(error: rw.errors.full_messages.join(", "))
          end

          rw
        end

        registration.update!(
          has_workshop_override: true,
          workshop_override_backup: backup_rows
        )
        registration.detect_conflict!
        context.registration_workshops = registration_workshops
      end
    end
  end
end
