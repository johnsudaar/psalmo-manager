require "csv"

module Importers
  # Processes the "FIltres" tab export: ticket number + forced workshop assignments.
  # Creates or replaces registration_workshop records with is_override: true.
  class FiltresCsvImporter
    # Column A is the ticket number; all other columns are workshop names.
    TICKET_COLUMN = "Numéro de billet"

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
      ticket_id = row[TICKET_COLUMN].to_s.strip
      return if ticket_id.blank?

      registration = Registration.find_by!(helloasso_ticket_id: ticket_id)

      workshop_columns(row.headers).each do |col|
        value = row[col].to_s.strip
        next if value.blank? || value == "0"

        workshop_name = col.strip
        workshop      = Workshop.find_by!(edition: @edition, name: workshop_name)
        price_cents   = parse_cents(value)

        # Remove any existing non-override record for this workshop, then upsert override
        rw = registration.registration_workshops.find_or_initialize_by(workshop: workshop)
        rw.price_paid_cents = price_cents
        rw.is_override      = true
        rw.save!
      end

      @applied += 1
    end

    def workshop_columns(headers)
      headers.reject { |h| h.to_s.strip == TICKET_COLUMN }
    end

    def parse_cents(str)
      return 0 if str.blank?
      cleaned = str.to_s.gsub(/[€\s]/, "").gsub(",", ".")
      (cleaned.to_f * 100).round
    end
  end
end
