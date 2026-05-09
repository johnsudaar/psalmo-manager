module Actors
  class TriggerHelloassoSync
    include Interactor

    def call
      edition = context.edition
      context.fail!(error: "Edition manquante") unless edition

      HelloassoSyncJob.perform_later(edition.id)
    end
  end
end
