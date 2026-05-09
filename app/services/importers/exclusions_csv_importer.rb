require "csv"

module Importers
  # Processes the "Calcul Statistiques" tab export: sets excluded_from_stats: true
  # on registrations whose ticket IDs appear in the file.
  #
  # Expected CSV format: single column "Numéro de billet" (or first column used as fallback).
  class ExclusionsCsvImporter
    include AuditSuppression

    def initialize(csv_path:, edition_id:)
      @csv_path   = csv_path
      @edition_id = edition_id
      @edition    = Edition.find(edition_id)
      @applied    = 0
      @errors     = []
    end

    def call
      without_audit_log do
        CSV.foreach(@csv_path, headers: true, encoding: "bom|utf-8") do |row|
          process_row(row)
        rescue => e
          @errors << "Row #{$.}: #{e.message}"
        end
      end
      { applied: @applied, errors: @errors }
    end

    private

    def process_row(row)
      # Accept either named column or first column
      ticket_id = (row["Numéro de billet"] || row.fields.first).to_s.strip
      return if ticket_id.blank?

      registration = Registration.find_by!(helloasso_ticket_id: ticket_id)
      registration.update_column(:excluded_from_stats, true)
      @applied += 1
    end
  end
end
