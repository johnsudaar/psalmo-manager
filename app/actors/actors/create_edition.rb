module Actors
  class CreateEdition
    include Interactor

    def call
      edition = Edition.new(context.edition_params)

      unless edition.save
        context.fail!(error: edition.errors.full_messages.join(", "))
      end

      context.edition = edition
    end
  end
end
