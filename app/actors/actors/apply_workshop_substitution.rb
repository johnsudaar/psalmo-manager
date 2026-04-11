module Actors
  class ApplyWorkshopSubstitution
    include Interactor

    def call
      registration = context.registration
      workshop     = context.workshop

      unless workshop.edition_id == registration.edition_id
        context.fail!(error: "Atelier hors édition")
      end

      # Remove any existing registration_workshop for the same time_slot
      registration.registration_workshops
                  .joins(:workshop)
                  .where(workshops: { time_slot: workshop.time_slot })
                  .destroy_all

      rw = registration.registration_workshops.build(
        workshop:        workshop,
        price_paid_cents: 0,
        is_override:     true
      )

      unless rw.save
        context.fail!(error: rw.errors.full_messages.join(", "))
      end

      context.registration_workshop = rw
    end
  end
end
