module Helloasso
  class SyncService
    def initialize(edition)
      @edition = edition
      @client  = Client.new
    end

    def call
      page = 1
      loop do
        resp = @client.get(
          "/v5/organizations/#{org_slug}/forms/Event/#{@edition.helloasso_form_slug}/orders",
          pageIndex: page, pageSize: 50, withDetails: true
        )
        data = resp.body
        data["data"].each { |order_data| process_order(order_data) }
        break if page >= data.dig("pagination", "totalPages").to_i
        page += 1
      end
    end

    # Called directly by WebhookProcessor for single-order updates
    def process_order(data)
      payer  = upsert_person(data["payer"])
      order  = upsert_order(data, payer)
      data["items"]&.each { |item_data| process_item(item_data, order) }
    end

    private

    def org_slug
      ENV["HELLOASSO_ORG_SLUG"]
    end

    def upsert_person(attrs)
      email = attrs["email"].presence
      dob   = parse_date(attrs["dateOfBirth"])

      person = if email
        Person.find_or_initialize_by(email: email)
      else
        Person.find_or_initialize_by(
          first_name: attrs["firstName"],
          last_name:  attrs["lastName"]
        )
      end

      person.assign_attributes(
        first_name:    attrs["firstName"],
        last_name:     attrs["lastName"],
        email:         email,
        date_of_birth: dob
      )
      person.save!
      person
    end

    def upsert_order(data, payer)
      order = Order.find_or_initialize_by(helloasso_order_id: data["id"].to_s)

      promo        = data["discount"]
      promo_code   = promo&.dig("code").presence
      promo_amount = promo ? (promo["amount"].to_f * 100).round : 0

      order.assign_attributes(
        edition:            @edition,
        payer:              payer,
        order_date:         Time.parse(data["date"]),
        status:             :confirmed,
        promo_code:         promo_code,
        promo_amount_cents: promo_amount,
        helloasso_raw:      data
      )
      order.save!
      order
    end

    def process_item(item_data, order)
      participant = upsert_person(item_data)
      registration = upsert_registration(item_data, order, participant)
      upsert_registration_workshops(registration, item_data)
    end

    def upsert_registration(item_data, order, person)
      registration = Registration.find_or_initialize_by(
        helloasso_ticket_id: item_data["id"].to_s
      )

      dob          = parse_date(item_data["dateOfBirth"])
      age_category = Registration.age_category_for(dob, @edition.start_date)

      registration.assign_attributes(
        order:              order,
        person:             person,
        edition:            @edition,
        ticket_price_cents: (item_data["initialAmount"].to_f * 100).round,
        discount_cents:     (item_data["discount"].to_f * 100).round,
        age_category:       age_category,
        helloasso_raw:      item_data
      )
      registration.save!
      registration
    end

    def upsert_registration_workshops(registration, item_data)
      # Delete non-override rows; override rows are sticky (preservation contract)
      registration.registration_workshops.where(is_override: false).destroy_all

      item_data["customFields"]&.each do |field|
        next if field["answer"].blank?

        workshop = @edition.workshops.find_by(name: field["answer"].upcase)
        unless workshop
          Rails.logger.warn(
            "[Helloasso::SyncService] Workshop not found: '#{field["answer"]}' " \
            "(edition #{@edition.id})"
          )
          next
        end

        registration.registration_workshops.create!(
          workshop:        workshop,
          price_paid_cents: 0,
          is_override:     false
        )
      end
    end

    def parse_date(value)
      return nil if value.blank?
      Date.parse(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
