require "csv"

module Importers
  class ParticipantsCsvImporter
    # Columns that are NOT workshop columns
    KNOWN_COLUMNS = %w[
      Numéro\ de\ billet
      Référence\ commande
      Nom
      Prénom
      Téléphone
      E-mail
      Date\ de\ naissance
      Tarif
      Réduction
      Tarif\ réel
      Date\ de\ la\ commande
      Nom\ payeur
      Prénom\ payeur
      E-mail\ payeur
      Téléphone\ payeur
      Code\ promo
      Montant\ de\ la\ réduction
      Inscription\ Semaine
      Age
      Age\ 10aine
    ].freeze

    def initialize(csv_path:, edition_id:)
      @csv_path   = csv_path
      @edition_id = edition_id
      @edition    = Edition.find(edition_id)
      @created    = 0
      @updated    = 0
      @errors     = []
      @workshop_cache = {}
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

    def workshop_columns(headers)
      headers.reject { |h| KNOWN_COLUMNS.include?(h.to_s.strip) }
    end

    def process_row(row)
      ticket_id = row["Numéro de billet"].to_s.strip
      order_ref = row["Référence commande"].to_s.strip

      # Find or create participant person
      participant = find_or_create_participant(row)

      # Find or create payer person (may be same as participant)
      payer = find_or_create_payer(row, participant)

      # Find or create order
      order = find_or_create_order(row, order_ref, payer)

      # Find or create registration
      reg, created = find_or_create_registration(row, ticket_id, order, participant)

      if created
        @created += 1
      else
        @updated += 1
      end

      # Process workshop columns (only for newly created or existing without overrides)
      process_workshops(row, reg)
    end

    def find_or_create_participant(row)
      last_name  = row["Nom"].to_s.strip
      first_name = row["Prénom"].to_s.strip
      email      = row["E-mail"].to_s.strip.presence
      phone      = row["Téléphone"].to_s.strip.presence
      dob_str    = row["Date de naissance"].to_s.strip.presence
      dob        = dob_str ? parse_date(dob_str) : nil

      # Match by email if present, otherwise name
      person = if email.present?
        Person.find_or_initialize_by(email: email)
      else
        Person.find_or_initialize_by(first_name: first_name, last_name: last_name)
      end

      person.last_name    = last_name
      person.first_name   = first_name
      person.email        = email if email.present?
      person.phone        = phone if phone.present?
      person.date_of_birth = dob if dob
      person.save!
      person
    end

    def find_or_create_payer(row, participant)
      payer_last  = row["Nom payeur"].to_s.strip
      payer_first = row["Prénom payeur"].to_s.strip
      payer_email = row["E-mail payeur"].to_s.strip.presence
      payer_phone = row["Téléphone payeur"].to_s.strip.presence

      # Check if payer == participant
      same_name  = payer_last.casecmp?(participant.last_name) && payer_first.casecmp?(participant.first_name)
      same_email = payer_email.blank? || payer_email == participant.email

      return participant if same_name && same_email

      payer = if payer_email.present?
        Person.find_or_initialize_by(email: payer_email)
      else
        Person.find_or_initialize_by(first_name: payer_first, last_name: payer_last)
      end

      payer.last_name  = payer_last  if payer_last.present?
      payer.first_name = payer_first if payer_first.present?
      payer.email      = payer_email if payer_email.present?
      payer.phone      = payer_phone if payer_phone.present?
      payer.save!
      payer
    end

    def find_or_create_order(row, order_ref, payer)
      order_date_str   = row["Date de la commande"].to_s.strip
      promo_code       = row["Code promo"].to_s.strip.presence
      promo_amount_str = row["Montant de la réduction"].to_s.strip

      order = Order.find_or_initialize_by(helloasso_order_id: order_ref)

      order.edition_id         = @edition.id
      order.payer_id           = payer.id
      order.order_date         = parse_datetime(order_date_str) if order_date_str.present?
      order.status             = :confirmed
      order.promo_code         = promo_code
      order.promo_amount_cents = parse_cents(promo_amount_str)
      order.save!
      order
    end

    def find_or_create_registration(row, ticket_id, order, participant)
      dob_str       = row["Date de naissance"].to_s.strip.presence
      dob           = dob_str ? parse_date(dob_str) : nil
      age_cat       = Registration.age_category_for(dob, @edition.start_date)
      ticket_price  = parse_cents(row["Tarif"].to_s.strip)
      discount      = parse_cents(row["Réduction"].to_s.strip)

      existing = Registration.find_by(helloasso_ticket_id: ticket_id)
      created  = existing.nil?

      reg = existing || Registration.new(helloasso_ticket_id: ticket_id)
      reg.order_id           = order.id
      reg.person_id          = participant.id
      reg.edition_id         = @edition.id
      reg.age_category       = age_cat
      reg.ticket_price_cents = ticket_price
      reg.discount_cents     = discount
      reg.save!
      [ reg, created ]
    end

    def process_workshops(row, registration)
      # Skip workshop columns that already have is_override: true records
      override_workshop_ids = registration.registration_workshops
                                          .where(is_override: true)
                                          .pluck(:workshop_id)

      workshop_columns(row.headers).each do |col|
        value = row[col].to_s.strip
        next if value.blank? || value == "0"

        price_cents = parse_cents(value)
        workshop    = find_or_create_workshop(col.strip)

        # Don't touch overridden workshops
        next if override_workshop_ids.include?(workshop.id)

        rw = registration.registration_workshops.find_or_initialize_by(workshop: workshop)
        rw.price_paid_cents = price_cents
        rw.is_override      = false
        rw.save!
      end
    end

    def find_or_create_workshop(name)
      normalized = name.strip
      @workshop_cache[normalized] ||=
        Workshop.find_or_create_by!(edition: @edition, name: normalized) do |w|
          w.time_slot               = :matin  # default; admin can update later
          w.helloasso_column_name   = normalized
        end
    end

    def parse_date(str)
      Date.strptime(str, "%d/%m/%Y")
    rescue ArgumentError, TypeError
      nil
    end

    def parse_datetime(str)
      # Supports "DD/MM/YYYY HH:MM" and "DD/MM/YYYY"
      if str.include?(" ")
        DateTime.strptime(str, "%d/%m/%Y %H:%M")
      else
        Date.strptime(str, "%d/%m/%Y").to_datetime
      end
    rescue ArgumentError, TypeError
      nil
    end

    def parse_cents(str)
      return 0 if str.blank?
      # Strip currency symbols, spaces; normalise comma → dot
      cleaned = str.to_s.gsub(/[€\s]/, "").gsub(",", ".")
      (cleaned.to_f * 100).round
    end
  end
end
