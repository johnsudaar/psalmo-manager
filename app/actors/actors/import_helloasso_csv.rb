module Actors
  class ImportHelloassoCsv
    include Interactor

    def call
      edition = context.edition
      file = context.file

      context.fail!(error: "Edition manquante") unless edition
      context.fail!(error: "Fichier CSV manquant") unless file

      result = Importers::ParticipantsCsvImporter.new(
        csv_path: file.path,
        edition_id: edition.id
      ).call

      context.result = result
    rescue StandardError => e
      context.fail!(error: e.message)
    end
  end
end
