require "csv"

class ExportsController < ApplicationController
  def index
  end

  def import_helloasso_csv
    result = Actors::ImportHelloassoCsv.call(
      edition: current_edition,
      file: params[:csv_file]
    )

    if result.success?
      summary = result.result
      message = [
        "Import HelloAsso terminé.",
        "#{summary[:created]} inscriptions créées",
        "#{summary[:updated]} mises à jour"
      ].join(" ")

      if summary[:errors].any?
        redirect_to export_path, alert: "#{message} #{summary[:errors].count} erreur(s)."
      else
        redirect_to export_path, notice: message
      end
    else
      redirect_to export_path, alert: result.error
    end
  end

  # GET /exports/participants
  # Columns: Prénom, Nom, Email, Téléphone, DDN, Catégorie, Ateliers, Exclu stats, Mineur seul
  def participants
    registrations = current_edition.registrations
      .includes(:person, :workshops)
      .order("people.last_name, people.first_name")

    csv = build_csv do |csv|
      csv << %w[Prénom Nom Email Téléphone DDN Catégorie Ateliers "Exclu stats" "Mineur seul"]
      registrations.each do |reg|
        person    = reg.person
        ateliers  = reg.workshops.map(&:name).join(" | ")
        csv << [
          person.first_name,
          person.last_name,
          person.email,
          person.phone,
          format_date_csv(person.date_of_birth),
          age_category_label(reg.age_category),
          ateliers,
          reg.excluded_from_stats ? "Oui" : "Non",
          reg.is_unaccompanied_minor ? "Oui" : "Non"
        ]
      end
    end

    send_csv csv, "participants_#{current_edition.year}.csv"
  end

  # GET /exports/workshop-roster
  # One section per workshop: workshop name header, then participant rows
  def workshop_roster_csv
    workshops = current_edition.workshops
      .includes(registrations: :person)
      .order(:time_slot, :name)

    csv = build_csv do |csv|
      workshops.each do |workshop|
        csv << [ workshop.name, TIME_SLOT_LABELS.fetch(workshop.time_slot, workshop.time_slot) ]
        csv << %w[Prénom Nom Catégorie Téléphone Email]
        registrations = workshop.registrations.sort_by { |r| r.person.last_name }
        registrations.each do |reg|
          person = reg.person
          csv << [
            person.first_name,
            person.last_name,
            age_category_label(reg.age_category),
            person.phone,
            person.email
          ]
        end
        csv << []  # blank separator between workshops
      end
    end

    send_csv csv, "listes_ateliers_#{current_edition.year}.csv"
  end

  # GET /exports/staff-summary
  # One row per staff profile with all financial fields
  def staff_summary
    profiles = current_edition.staff_profiles
      .includes(:person, :staff_advances, :staff_payments)
      .order(:dossier_number)

    csv = build_csv do |csv|
      csv << [
        "N° dossier", "Nom", "Prénom",
        "Indemnités (€)", "Déplacement (€)", "Fournitures (€)", "Total à payer (€)",
        "Héberg. Psalmodia (€)", "Repas Psalmodia (€)", "Billets Psalmodia (€)", "Total Psalmodia (€)",
        "Héberg. membres (€)", "Repas membres (€)", "Billets membres (€)", "Total membres (€)",
        "Montant dû (€)", "Total acomptes (€)", "Total versements (€)", "Solde (€)"
      ]
      profiles.each do |sp|
        csv << [
          sp.dossier_number,
          sp.person&.last_name || sp.last_name,
          sp.person&.first_name || sp.first_name,
          cents_to_euros(sp.allowance_cents),
          cents_to_euros(sp.travel_allowance_cents),
          cents_to_euros(sp.supplies_cost_cents),
          cents_to_euros(sp.total_to_pay_instructor_cents),
          cents_to_euros(sp.accommodation_cost_cents),
          cents_to_euros(sp.meals_cost_cents),
          cents_to_euros(sp.tickets_cost_cents),
          cents_to_euros(sp.total_psalmodia_covers_cents),
          cents_to_euros(sp.member_uncovered_accommodation_cents),
          cents_to_euros(sp.member_uncovered_meals_cents),
          cents_to_euros(sp.member_uncovered_tickets_cents),
          cents_to_euros(sp.total_member_uncovered_cents),
          cents_to_euros(sp.amount_owed_to_instructor_cents),
          cents_to_euros(sp.total_advances_cents),
          cents_to_euros(sp.total_payments_cents),
          cents_to_euros(sp.balance_cents)
        ]
      end
    end

    send_csv csv, "recapitulatif_staff_#{current_edition.year}.csv"
  end

  # GET /exports/financial-report
  # Aggregated financial totals for the edition
  def financial_report
    registrations = current_edition.registrations.includes(:person)
    for_stats     = registrations.for_stats

    csv = build_csv do |csv|
      csv << [ "Indicateur", "Valeur" ]
      csv << [ "Édition", current_edition.year ]
      csv << [ "Total participants", registrations.count ]
      csv << [ "Participants (stats)", for_stats.count ]
      csv << [ "Participants enfant", for_stats.enfant.count ]
      csv << [ "Participants adulte", for_stats.adulte.count ]
      csv << [ "Mineurs non accompagnés", registrations.unaccompanied_minors.count ]
      csv << [ "Inscriptions avec conflit", registrations.with_conflicts.count ]
      csv << []
      csv << [ "Total billetterie (€)", cents_to_euros(for_stats.sum(:ticket_price_cents)) ]
      csv << [ "Total remises (€)", cents_to_euros(for_stats.sum(:discount_cents)) ]
      csv << [ "Total net (€)", cents_to_euros(for_stats.sum("ticket_price_cents - discount_cents")) ]
    end

    send_csv csv, "rapport_financier_#{current_edition.year}.csv"
  end

  # GET /exports/orders-csv
  # One row per order: Payeur, Email, Téléphone, Nb participants, Participants
  def orders_csv
    orders = current_edition.orders
      .includes(:payer, registrations: :person)
      .order(:order_date)

    csv = build_csv do |csv|
      csv << [ "Date commande", "ID HelloAsso", "Statut", "Payeur", "Email payeur", "Téléphone payeur",
               "Nb participants", "Participants" ]
      orders.each do |order|
        payer        = order.payer
        participants = order.registrations.map { |r| r.person.full_name }.join(" | ")
        csv << [
          format_date_csv(order.order_date),
          order.helloasso_order_id,
          order.status,
          payer ? payer.full_name : "",
          payer ? payer.email.to_s : "",
          payer ? payer.phone.to_s : "",
          order.registrations.size,
          participants
        ]
      end
    end

    send_csv csv, "commandes_#{current_edition.year}.csv"
  end

  private

  TIME_SLOT_LABELS = {
    "matin"      => "Matin",
    "apres_midi" => "Après-midi",
    "journee"    => "Journée"
  }.freeze

  def build_csv(&block)
    # UTF-8 BOM so Excel opens it correctly
    "\xEF\xBB\xBF" + CSV.generate(col_sep: ";", &block)
  end

  def send_csv(csv_string, filename)
    send_data csv_string,
              filename:    filename,
              type:        "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  def cents_to_euros(cents)
    return "" if cents.nil?
    "%.2f" % (cents / 100.0)
  end

  def age_category_label(category)
    case category
    when "enfant", :enfant then "Enfant"
    when "adulte", :adulte then "Adulte"
    else category.to_s.capitalize
    end
  end

  def format_date_csv(date)
    date ? date.strftime("%d/%m/%Y") : ""
  end
end
