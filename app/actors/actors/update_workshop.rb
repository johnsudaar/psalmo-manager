module Actors
  class UpdateWorkshop
    include Interactor

    def call
      workshop = context.workshop

      unless workshop.update(context.workshop_params)
        context.fail!(error: workshop.errors.full_messages.join(", "))
      end
    end
  end
end
