class WorkshopRosterPdf
  include Prawn::View

  INDIGO    = "4338CA"
  INDIGO_BG = "EEF2FF"
  GRAY      = "6B7280"
  RULE      = "E5E7EB"
  BLACK     = "111827"

  TIME_SLOT_LABELS = {
    "matin"     => "Matin",
    "apres_midi" => "Après-midi",
    "journee"   => "Journée"
  }.freeze

  def initialize(workshop)
    @workshop  = workshop
    @edition   = workshop.edition
    @document  = Prawn::Document.new(
      page_size:   "A4",
      page_layout: :portrait,
      margin:      [ mm(20), mm(20), mm(20), mm(20) ]
    )
    font "Helvetica"
    fill_color BLACK
  end

  def render
    build
    document.render
  end

  private

  def build
    header
    move_down 12
    participants_table
    footer
  end

  def header
    fill_color INDIGO
    font_size(16) { text "PSALMODIA GAGNIÈRES", style: :bold }
    fill_color BLACK
    font_size(11) { text "Stage artistique d'été #{@edition.year}" }
    move_down 6
    fill_color INDIGO
    font_size(13) { text "LISTE DE PRÉSENCE — ATELIER", style: :bold }
    fill_color BLACK
    move_down 6
    font_size(10) do
      text "Atelier : #{@workshop.name}"
      text "Créneau : #{TIME_SLOT_LABELS.fetch(@workshop.time_slot, @workshop.time_slot)}"
      if @workshop.capacity
        text "Capacité : #{@workshop.capacity} place(s)"
      end
    end
    move_down 6
    stroke_color RULE
    stroke_horizontal_rule
    stroke_color BLACK
    move_down 8
  end

  def participants_table
    registrations = @workshop.registrations
      .includes(:person)
      .order("people.last_name, people.first_name")

    if registrations.empty?
      fill_color GRAY
      font_size(10) { text "Aucun participant inscrit.", style: :italic }
      fill_color BLACK
      return
    end

    header_row = [
      [ "Nom", "Prénom", "Catégorie", "Téléphone", "Email", "Présence" ]
    ]

    data_rows = registrations.map do |reg|
      person = reg.person
      [
        person.last_name.to_s,
        person.first_name.to_s,
        age_category_label(reg.age_category),
        person.phone.to_s,
        person.email.to_s,
        ""
      ]
    end

    col_widths = compute_col_widths

    table(
      header_row + data_rows,
      width: bounds.width,
      column_widths: col_widths,
      header: true,
      cell_style: { size: 9, padding: [ 4, 4, 4, 4 ] }
    ) do
      # Header row styling
      row(0).background_color = INDIGO
      row(0).text_color       = "FFFFFF"
      row(0).font_style       = :bold
      row(0).borders          = []

      # Alternating body rows
      rows(1..-1).each_with_index do |_, i|
        rows(i + 1).background_color = i.even? ? "FFFFFF" : "F9FAFB"
        rows(i + 1).borders = [ :bottom ]
        rows(i + 1).border_color = RULE
      end
    end

    move_down 8
    fill_color GRAY
    font_size(9) { text "Total inscrits : #{registrations.size}" }
    fill_color BLACK
  end

  def footer
    move_down 8
    stroke_color RULE
    stroke_horizontal_rule
    stroke_color BLACK
    move_down 4
    fill_color GRAY
    font_size(8) do
      text "Document généré le #{Date.today.strftime('%d/%m/%Y')} — Psalmodia #{@edition.year}",
           align: :right
    end
    fill_color BLACK
  end

  def age_category_label(category)
    case category
    when "enfant", :enfant then "Enfant"
    when "adulte", :adulte then "Adulte"
    else category.to_s.capitalize
    end
  end

  def compute_col_widths
    total = bounds.width
    # Nom, Prénom, Catégorie, Téléphone, Email, Présence
    ratios = [ 0.17, 0.15, 0.10, 0.15, 0.30, 0.13 ]
    widths = ratios.map { |r| (total * r).floor }
    # Give leftover pixels to the last column to avoid CannotFit errors
    widths[-1] = total - widths[0..-2].sum
    widths
  end

  def mm(val)
    val * 2.8346
  end
end
