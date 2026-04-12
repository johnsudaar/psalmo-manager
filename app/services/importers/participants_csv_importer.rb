require "csv"

module Importers
  class ParticipantsCsvImporter
    # All non-workshop columns in the HelloAsso export format
    KNOWN_COLUMNS = %w[
      Référence\ commande
      Date\ de\ la\ commande
      Statut\ de\ la\ commande
      Nom\ participant
      Prénom\ participant
      Nom\ payeur
      Prénom\ payeur
      Email\ payeur
      Raison\ sociale
      Moyen\ de\ paiement
      Billet
      Numéro\ de\ billet
      Tarif
      Montant\ tarif
      Code\ Promo
      Montant\ code\ promo
      Date\ de\ naissance
      Adresse\ postale\ complète\ (rue,\ ville,\ pays)
      N°\ de\ téléphone
    ].freeze

    # Columns that are "Montant X" companions to workshop columns — also not workshops
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
      # HelloAsso exports can contain stray quotes in free-text fields, especially addresses.
      CSV.foreach(@csv_path, **csv_options) do |row|
        # Skip cancelled/pending orders
        next if row["Statut de la commande"].to_s.strip != "Validé"
        process_row(row)
      rescue => e
        @errors << "Row #{$.}: #{e.message}"
      end
      { created: @created, updated: @updated, errors: @errors }
    end

    private

    def csv_options
      {
        headers: true,
        encoding: "bom|utf-8",
        liberal_parsing: true,
        col_sep: detected_col_sep
      }
    end

    def detected_col_sep
      header_line = File.open(@csv_path, "rb", &:gets).to_s.encode("UTF-8", invalid: :replace, undef: :replace)

      header_line.count(";") > header_line.count(",") ? ";" : ","
    end

    # Workshop columns: not in KNOWN_COLUMNS and not a "Montant X" companion
    def workshop_columns(headers)
      headers.reject do |h|
        h = h.to_s.strip
        KNOWN_COLUMNS.include?(h) || h.start_with?("Montant ")
      end
    end

    def process_row(row)
      ticket_id = row["Numéro de billet"].to_s.strip
      order_ref = row["Référence commande"].to_s.strip

      participant = find_or_create_participant(row)
      payer       = find_or_create_payer(row, participant)
      order       = find_or_create_order(row, order_ref, payer)
      reg, created = find_or_create_registration(row, ticket_id, order, participant)

      if created
        @created += 1
      else
        @updated += 1
      end

      process_workshops(row, reg)
    end

    def find_or_create_participant(row)
      last_name  = row["Nom participant"].to_s.strip
      first_name = row["Prénom participant"].to_s.strip
      phone      = row["N° de téléphone"].to_s.strip.presence
      dob_str    = row["Date de naissance"].to_s.strip.presence
      dob        = dob_str ? parse_date(dob_str) : nil

      # No participant email in this export format — match by name
      person = Person.find_or_initialize_by(first_name: first_name, last_name: last_name)
      person.last_name     = last_name
      person.first_name    = first_name
      person.phone         = phone if phone.present?
      person.date_of_birth = dob if dob
      person.save!
      person
    end

    def find_or_create_payer(row, participant)
      payer_last  = row["Nom payeur"].to_s.strip
      payer_first = row["Prénom payeur"].to_s.strip
      payer_email = row["Email payeur"].to_s.strip.presence

      same_name = payer_last.casecmp?(participant.last_name) &&
                  payer_first.casecmp?(participant.first_name)

      return participant if same_name && payer_email.blank?

      payer = if payer_email.present?
        Person.find_or_initialize_by(email: payer_email)
      else
        Person.find_or_initialize_by(first_name: payer_first, last_name: payer_last)
      end

      payer.last_name  = payer_last  if payer_last.present?
      payer.first_name = payer_first if payer_first.present?
      payer.email      = payer_email if payer_email.present?
      payer.save!
      payer
    end

    def find_or_create_order(row, order_ref, payer)
      order_date_str   = row["Date de la commande"].to_s.strip
      promo_code       = row["Code Promo"].to_s.strip.presence
      promo_amount_str = row["Montant code promo"].to_s.strip

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
      dob_str      = row["Date de naissance"].to_s.strip.presence
      dob          = dob_str ? parse_date(dob_str) : nil
      age_cat      = Registration.age_category_for(dob, @edition.start_date)
      tariff_label = row["Tarif"].to_s.strip.presence
      ticket_price = parse_cents(row["Montant tarif"].to_s.strip)
      discount     = parse_cents(row["Montant code promo"].to_s.strip)

      existing = Registration.find_by(helloasso_ticket_id: ticket_id)
      created  = existing.nil?

      reg = existing || Registration.new(helloasso_ticket_id: ticket_id)
      reg.order_id           = order.id
      reg.person_id          = participant.id
      reg.edition_id         = @edition.id
      reg.age_category       = age_cat
      reg.tariff_label       = tariff_label
      reg.ticket_price_cents = ticket_price
      reg.discount_cents     = discount
      reg.save!
      [ reg, created ]
    end

    def process_workshops(row, registration)
      return if registration.has_workshop_override?

      workshop_columns(row.headers).each do |col|
        value = row[col].to_s.strip
        # Workshop column contains "Oui" when enrolled
        next unless value.casecmp?("oui")

        price_cents = parse_cents(row["Montant #{col.strip}"].to_s.strip)
        workshop    = find_or_create_workshop(col.strip)

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
          w.time_slot             = infer_time_slot(normalized)
          w.helloasso_column_name = normalized
        end
    end

    # Infer time_slot from workshop name conventions in the CSV headers
    def infer_time_slot(name)
      n = name.downcase
      return :journee if n.include?("journée") || n.include?("journee")
      return :apres_midi if n.include?("après midi") || n.include?("apres midi") || n.include?("après-midi")
      :matin
    end

    def parse_date(str)
      # Try D/M/YYYY and DD/MM/YYYY
      Date.strptime(str, "%d/%m/%Y")
    rescue ArgumentError, TypeError
      begin
        Date.strptime(str, "%-d/%-m/%Y")
      rescue
        nil
      end
    end

    def parse_datetime(str)
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
      cleaned = str.to_s.gsub(/[€\s]/, "").gsub(",", ".")
      (cleaned.to_f * 100).round
    end
  end
end
