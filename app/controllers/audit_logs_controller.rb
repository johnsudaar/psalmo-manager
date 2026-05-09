class AuditLogsController < ApplicationController
  FIELD_LABELS = {
    "name" => "Nom",
    "year" => "Année",
    "start_date" => "Date de début",
    "end_date" => "Date de fin",
    "email" => "Email",
    "phone" => "Téléphone",
    "first_name" => "Prénom",
    "last_name" => "Nom",
    "time_slot" => "Créneau",
    "capacity" => "Capacité",
    "age_category" => "Catégorie",
    "excluded_from_stats" => "Exclu des stats",
    "is_unaccompanied_minor" => "Mineur non accompagné",
    "has_conflict" => "Conflit atelier",
    "notes" => "Commentaire",
    "transport_mode" => "Transport",
    "km_traveled" => "Km parcourus",
    "allowance_cents" => "Indemnité",
    "supplies_cost_cents" => "Fournitures",
    "accommodation_cost_cents" => "Hébergement",
    "meals_cost_cents" => "Repas",
    "tickets_cost_cents" => "Billets"
  }.freeze

  helper_method :human_event, :resource_label, :change_lines

  def index
    @versions = PaperTrail::Version.order(created_at: :desc).limit(100)
  end

  private

  def human_event(version)
    {
      "create" => "Création",
      "update" => "Modification",
      "destroy" => "Suppression"
    }[version.event] || version.event
  end

  def resource_label(version)
    item = version.item
    base = case version.item_type
    when "Edition"
      item&.name || "Édition ##{version.item_id}"
    when "Workshop"
      item&.name || "Atelier ##{version.item_id}"
    when "Person"
      item&.full_name || "Participant ##{version.item_id}"
    when "Registration"
      item&.helloasso_ticket_id || "Inscription ##{version.item_id}"
    when "Order"
      item&.helloasso_order_id || "Commande ##{version.item_id}"
    when "StaffProfile"
      "Fiche staff ##{version.item_id}"
    when "User"
      item&.email || "Utilisateur ##{version.item_id}"
    else
      "#{version.item_type} ##{version.item_id}"
    end

    "#{version.item_type} · #{base}"
  end

  def change_lines(version)
    return [] unless version.event == "update" && version.object.present?

    previous = YAML.safe_load(version.object, permitted_classes: [ Time, Date, Symbol, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone ], aliases: true) || {}
    current = version.item
    return [] unless current

    previous.filter_map do |field, old_value|
      next if field == "updated_at"

      new_value = current.public_send(field) if current.respond_to?(field)
      next if old_value.to_s == new_value.to_s

      "#{FIELD_LABELS[field] || field.humanize} : #{format_value(old_value)} -> #{format_value(new_value)}"
    end.first(6)
  rescue Psych::SyntaxError
    []
  end

  def format_value(value)
    case value
    when TrueClass then "Oui"
    when FalseClass then "Non"
    when NilClass then "vide"
    when Date then value.strftime("%d/%m/%Y")
    when Time, ActiveSupport::TimeWithZone then value.strftime("%d/%m/%Y %H:%M")
    else value.to_s.truncate(80)
    end
  end
end
