require "csv"

module Importers
  # Imports the "Recapitulatif Frais Animateur" tab from Sheet 2.
  # Creates/updates Person and StaffProfile records.
  #
  # Column mapping (zero-indexed, Google Sheets A=0):
  #   A  Identifiant          → staff_profiles.internal_id
  #   B  Nom                  → people.last_name
  #   C  Prénom               → people.first_name
  #   D  Mode de déplacement  → staff_profiles.transport_mode
  #   E  KM Parcourus         → staff_profiles.km_traveled
  #   F  Indemnités           → staff_profiles.allowance_cents
  #   G  Frais de déplacement → computed, skip
  #   H  Frais fournitures    → staff_profiles.supplies_cost_cents
  #   I  Total frais          → computed, skip
  #   J  Hébergement (PC)     → staff_profiles.accommodation_cost_cents
  #   K  Repas (PC)           → staff_profiles.meals_cost_cents
  #   L  Billets/Ateliers(PC) → staff_profiles.tickets_cost_cents
  #   M  Total (anim PC)      → computed, skip
  #   N  Hébergement non PC   → staff_profiles.member_uncovered_accommodation_cents
  #   O  Repas non PC         → staff_profiles.member_uncovered_meals_cents
  #   P  Billets non PC       → staff_profiles.member_uncovered_tickets_cents
  #   Q  Total membres        → computed, skip
  #   R  Billets mbr PC       → staff_profiles.member_covered_tickets_cents
  #   S  Total mbr PC         → computed, skip
  #   T  À payer animateur    → computed, skip
  #   U  Montant reçu         → handled by VersementsCsvImporter, skip
  #   V  Solde                → computed, skip
  #   W  Coût animateur       → computed, skip
  #   X  Nom indemnité        → staff_profiles.allowance_label
  #   Y  Commentaires         → staff_profiles.notes
  class StaffCsvImporter
    COLUMN_MAP = {
      "Identifiant"                      => :internal_id,
      "Nom"                              => :last_name,
      "Prénom"                           => :first_name,
      "Mode de déplacement"              => :transport_mode,
      "KM Parcourus"                     => :km_traveled,
      "Indemnités"                       => :allowance_cents,
      "Frais fournitures atelier"        => :supplies_cost_cents,
      "Hébergement (pris en charge)"     => :accommodation_cost_cents,
      "Repas (pris en charge)"           => :meals_cost_cents,
      "Billets/Ateliers (pris en charge)" => :tickets_cost_cents,
      "Hébergement non pris en charge"   => :member_uncovered_accommodation_cents,
      "Repas non pris en charge"         => :member_uncovered_meals_cents,
      "Billets non pris en charge"       => :member_uncovered_tickets_cents,
      "Billets membres pris en charge"   => :member_covered_tickets_cents,
      "Nom indemnité"                    => :allowance_label,
      "Commentaires"                     => :notes
    }.freeze

    CENTS_FIELDS = %i[
      allowance_cents
      supplies_cost_cents
      accommodation_cost_cents
      meals_cost_cents
      tickets_cost_cents
      member_uncovered_accommodation_cents
      member_uncovered_meals_cents
      member_uncovered_tickets_cents
      member_covered_tickets_cents
    ].freeze

    def initialize(csv_path:, edition_id:)
      @csv_path   = csv_path
      @edition_id = edition_id
      @edition    = Edition.find(edition_id)
      @created    = 0
      @updated    = 0
      @errors     = []
    end

    def call
      CSV.foreach(@csv_path, headers: true, encoding: "bom|utf-8") do |row|
        process_row(row)
      rescue => e
        @errors << "Row #{$.}: #{e.message}"
      end
      { created: @created, updated: @updated, errors: @errors }
    end

    private

    def process_row(row)
      # Build a normalised attrs hash using column header → field mapping
      attrs = {}
      COLUMN_MAP.each do |col, field|
        value = row[col]
        next if value.nil?
        attrs[field] = value.to_s.strip
      end

      internal_id = attrs[:internal_id].presence
      last_name   = attrs[:last_name].presence
      first_name  = attrs[:first_name].presence

      # Skip blank / header-like rows
      return if last_name.blank? && first_name.blank?

      person = find_or_create_person(last_name, first_name)

      profile = StaffProfile.find_by(person: person, edition: @edition) ||
                StaffProfile.new(person: person, edition: @edition)
      created = profile.new_record?

      profile.internal_id    = internal_id
      profile.transport_mode = attrs[:transport_mode].presence
      profile.km_traveled    = attrs[:km_traveled].presence&.gsub(",", ".")&.to_f || 0
      profile.allowance_label = attrs[:allowance_label].presence
      profile.notes           = attrs[:notes].presence

      CENTS_FIELDS.each do |field|
        profile.public_send(:"#{field}=", parse_cents(attrs[field]))
      end

      profile.save!
      created ? @created += 1 : @updated += 1
    end

    def find_or_create_person(last_name, first_name)
      person = Person.find_by(last_name: last_name, first_name: first_name)
      return person if person

      Person.create!(last_name: last_name, first_name: first_name)
    end

    def parse_cents(str)
      return 0 if str.blank?
      cleaned = str.to_s.gsub(/[€\s]/, "").gsub(",", ".")
      (cleaned.to_f * 100).round
    end
  end
end
