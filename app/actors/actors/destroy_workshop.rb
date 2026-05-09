module Actors
  class DestroyWorkshop
    include Interactor

    def call
      workshop = context.workshop

      if workshop.registrations.any?
        context.fail!(error: "Impossible de supprimer un atelier avec des inscriptions.")
        return
      end

      workshop.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      context.fail!(error: e.message)
    end
  end
end
