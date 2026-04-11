require "csv"

module Importers
  # Processes the "Mineurs_Seuls" tab export: sets is_unaccompanied_minor: true
  # and responsible_person_note on matching registrations.
  #
  # Expected CSV columns:
  #   - "Numéro de billet" (or first column)
  #   - "Note" or "Responsable" (or second column) — free text
  class MineursCsvImporter
    NOTE_COLUMNS = %w[Note Responsable Commentaire].freeze

    def initialize(csv_path:, edition_id:)
      @csv_path   = csv_path
      @edition_id = edition_id
      @edition    = Edition.find(edition_id)
      @applied    = 0
      @errors     = []
    end

    def call
      CSV.foreach(@csv_path, headers: true, encoding: "bom|utf-8") do |row|
        process_row(row)
      rescue => e
        @errors << "Row #{$.}: #{e.message}"
      end
      { applied: @applied, errors: @errors }
    end

    private

    def process_row(row)
      ticket_id = (row["Numéro de billet"] || row.fields.first).to_s.strip
      return if ticket_id.blank?

      note_col = NOTE_COLUMNS.find { |c| row.headers.include?(c) }
      note     = note_col ? row[note_col].to_s.strip : row.fields[1].to_s.strip

      registration = Registration.find_by!(helloasso_ticket_id: ticket_id)
      registration.update_columns(
        is_unaccompanied_minor:   true,
        responsible_person_note:  note.presence
      )
      @applied += 1
    end
  end
end
