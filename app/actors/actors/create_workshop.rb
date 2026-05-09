module Actors
  class CreateWorkshop
    include Interactor

    def call
      workshop = context.edition.workshops.build(context.workshop_params)

      unless workshop.save
        context.fail!(error: workshop.errors.full_messages.join(", "))
      end

      context.workshop = workshop
    end
  end
end
