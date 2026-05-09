require "csv"

module Importers
  # Imports the "Versements" tab from Sheet 2.
  # Creates StaffAdvance or StaffPayment records.
  #
  # Column mapping:
  #   De          → internal_id of the sender
  #   A           → internal_id of the recipient
  #   Date        → date (DD/MM/YYYY)
  #   Montant     → amount_cents (× 100)
  #   Commentaire → comment
  #
  # Direction logic:
  #   - `De` matches a StaffProfile.internal_id → StaffAdvance (instructor → Psalmodia)
  #   - `A`  matches a StaffProfile.internal_id → StaffPayment  (Psalmodia → instructor)
  class VersementsCsvImporter
    def initialize(csv_path:, edition_id:)
      @csv_path   = csv_path
      @edition_id = edition_id
      @edition    = Edition.find(edition_id)
      @advances   = 0
      @payments   = 0
      @errors     = []
      # Cache internal_id → StaffProfile for the edition
      @profile_map = StaffProfile.where(edition: @edition)
                                 .where.not(internal_id: nil)
                                 .index_by(&:internal_id)
    end

    def call
      CSV.foreach(@csv_path, headers: true, encoding: "bom|utf-8") do |row|
        process_row(row)
      rescue => e
        @errors << "Row #{$.}: #{e.message}"
      end
      { advances: @advances, payments: @payments, errors: @errors }
    end

    private

    def process_row(row)
      from_id    = row["De"].to_s.strip
      to_id      = row["A"].to_s.strip
      date_str   = row["Date"].to_s.strip
      amount_str = row["Montant"].to_s.strip
      comment    = row["Commentaire"].to_s.strip.presence

      return if from_id.blank? && to_id.blank?

      date         = parse_date(date_str)
      amount_cents = parse_cents(amount_str)

      if (profile = @profile_map[from_id])
        # Instructor paid Psalmodia → StaffAdvance
        StaffAdvance.find_or_create_by!(
          staff_profile: profile,
          date:          date,
          amount_cents:  amount_cents,
          comment:       comment
        )
        @advances += 1
      elsif (profile = @profile_map[to_id])
        # Psalmodia paid instructor → StaffPayment
        StaffPayment.find_or_create_by!(
          staff_profile: profile,
          date:          date,
          amount_cents:  amount_cents,
          comment:       comment
        )
        @payments += 1
      end
      # If neither side matches a known profile, silently skip
    end

    def parse_date(str)
      Date.strptime(str, "%d/%m/%Y")
    rescue ArgumentError, TypeError
      Date.current
    end

    def parse_cents(str)
      return 0 if str.blank?
      cleaned = str.to_s.gsub(/[€\s]/, "").gsub(",", ".")
      (cleaned.to_f * 100).round
    end
  end
end
