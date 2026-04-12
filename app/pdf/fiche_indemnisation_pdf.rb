class FicheIndemnisationPdf
  include Prawn::View

  INDIGO    = "4338CA"
  INDIGO_BG = "EEF2FF"
  GRAY      = "6B7280"
  RULE      = "E5E7EB"
  BLACK     = "111827"

  def initialize(staff_profile)
    @sp       = staff_profile
    @edition  = staff_profile.edition
    @document = Prawn::Document.new(
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

  # ---------------------------------------------------------------
  # Top-level build
  # ---------------------------------------------------------------

  def build
    header
    move_down 10
    section_frais_animateur
    move_down 6
    section_frais_pris_en_charge
    move_down 6
    section_frais_membres
    move_down 6
    section_montant_du
    move_down 6
    section_acomptes
    move_down 6
    section_versements
    move_down 8
    section_soldes
    footer
  end

  # ---------------------------------------------------------------
  # Sections
  # ---------------------------------------------------------------

  def header
    fill_color INDIGO
    font_size(16) { text "PSALMODIA GAGNIÈRES", style: :bold }
    fill_color BLACK
    font_size(11) { text "Stage artistique d'été #{@edition.year}" }
    move_down 6
    fill_color INDIGO
    font_size(13) { text "FICHE D'INDEMNISATION ANIMATEUR(S)", style: :bold }
    fill_color BLACK
    move_down 6
    font_size(10) do
      text "Numéro de dossier : #{@sp.dossier_number}"
      text "Nom : #{@sp.full_name}"
    end
    move_down 6
    stroke_color RULE
    stroke_horizontal_rule
    stroke_color BLACK
    move_down 8
  end

  def section_frais_animateur
    section_header "RÉCAPITULATIF DES FRAIS DU/DES ANIMATEUR(S)"

    two_col_row @sp.effective_allowance_label, @sp.allowance_cents
    if @sp.km_traveled&.positive?
      rate = @sp.effective_km_rate_cents
      rate_label = @sp.km_rate_override_cents ? "(taux personnalisé)" : ""
      two_col_row "Frais de déplacement", @sp.travel_allowance_cents
      indent(12) do
        fill_color GRAY
        font_size(8) do
          text "(#{@sp.km_traveled} km × #{format_rate(rate)} €/km #{rate_label})" if @sp.travel_override_cents.blank?
        end
        fill_color BLACK
      end
    else
      two_col_row "Frais de déplacement", @sp.travel_allowance_cents
    end
    two_col_row "Frais fournitures atelier", @sp.supplies_cost_cents
    move_down 2
    two_col_row "Total frais à payer à animateur(s)", @sp.total_to_pay_instructor_cents, bold: true
  end

  def section_frais_pris_en_charge
    section_header "FRAIS ANIMATEUR(S) PRIS EN CHARGE PSALMODIA"

    two_col_row "Hébergement (pris en charge Psalmodia)", @sp.accommodation_cost_cents
    two_col_row "Repas (pris en charge Psalmodia)", @sp.meals_cost_cents
    two_col_row "Billet festivalier et/ou atelier (pris en charge Psalmodia)", @sp.tickets_cost_cents
    move_down 2
    two_col_row "Total frais animateur(s) pris en charge Psalmodia", @sp.total_psalmodia_covers_cents, bold: true
  end

  def section_frais_membres
    section_header "MONTANT DES FRAIS DU/DES MEMBRE(S) DE LA FAMILLE"

    fill_color GRAY
    font_size(8) { text "Non pris en charge", style: :bold }
    fill_color BLACK
    move_down 2

    two_col_row "Hébergement(s) non pris en charge", @sp.member_uncovered_accommodation_cents
    two_col_row "Repas non pris en charge", @sp.member_uncovered_meals_cents
    two_col_row "Billet(s) et atelier(s) non pris en charge par Psalmodia", @sp.member_uncovered_tickets_cents
    move_down 2
    two_col_row "Total des frais membre(s) à payer par animateur", @sp.total_member_uncovered_cents, bold: true

    move_down 4
    fill_color GRAY
    font_size(8) { text "Pris en charge Psalmodia", style: :bold }
    fill_color BLACK
    move_down 2

    two_col_row "Billet(s) et atelier(s) pris en charge par Psalmodia", @sp.member_covered_tickets_cents
    move_down 2
    two_col_row "Total des frais membres pris en charge Psalmodia", @sp.total_member_covered_cents, bold: true
  end

  def section_montant_du
    amount = format_euros(@sp.amount_owed_to_instructor_cents)
    bounding_box([ 0, cursor ], width: bounds.width, height: 28) do
      fill_color INDIGO_BG
      fill_rectangle [ 0, cursor ], bounds.width, 28
      fill_color INDIGO
      stroke_color INDIGO
      stroke_bounds
      stroke_color BLACK
      fill_color BLACK
      font_size(12) do
        text_box "Montant dû à l'animateur :    #{amount}",
                 at: [ 6, cursor - 6 ],
                 style: :bold,
                 width: bounds.width - 12
      end
    end
    move_down 4
  end

  def section_acomptes
    section_header "ACOMPTES PAYÉS PAR L'ANIMATEUR"
    advances = @sp.staff_advances.order(:date)
    if advances.empty?
      fill_color GRAY
      font_size(9) { text "Aucun acompte enregistré.", styles: [ :italic ] }
      fill_color BLACK
      move_down 2
      two_col_row "Total acompte(s)", 0, bold: true
    else
      advances_table(advances)
      two_col_row "Total acompte(s)", @sp.total_advances_cents, bold: true
    end
  end

  def section_versements
    section_header "MONTANTS VERSÉS À L'ANIMATEUR"
    payments = @sp.staff_payments.order(:date)
    if payments.empty?
      fill_color GRAY
      font_size(9) { text "Aucun versement enregistré.", styles: [ :italic ] }
      fill_color BLACK
      move_down 2
      two_col_row "Total versement(s)", 0, bold: true
    else
      payments_table(payments)
      two_col_row "Total versement(s)", @sp.total_payments_cents, bold: true
    end
  end

  def section_soldes
    balance = @sp.balance_cents
    owed_to_instructor = balance > 0 ? balance : 0
    owed_to_psalmodia  = balance < 0 ? balance.abs : 0

    # Psalmodia owes instructor
    bg = balance > 0 ? INDIGO_BG : "F9FAFB"
    bounding_box([ 0, cursor ], width: bounds.width, height: 20) do
      fill_color bg
      fill_rectangle [ 0, cursor ], bounds.width, 20
      fill_color balance > 0 ? INDIGO : BLACK
      font_size(10) do
        label = balance > 0 ? "Somme à payer à l'animateur :" : "Somme à payer à l'animateur :"
        val   = balance > 0 ? format_euros(owed_to_instructor) : "—"
        text_box "#{label}    #{val}",
                 at: [ 6, cursor - 4 ],
                 style: (balance > 0 ? :bold : :normal),
                 width: bounds.width - 12
      end
    end
    move_down 2

    # Instructor owes Psalmodia
    bg2 = balance < 0 ? "FEF2F2" : "F9FAFB"
    bounding_box([ 0, cursor ], width: bounds.width, height: 20) do
      fill_color bg2
      fill_rectangle [ 0, cursor ], bounds.width, 20
      fill_color balance < 0 ? "DC2626" : BLACK
      font_size(10) do
        val = balance < 0 ? format_euros(owed_to_psalmodia) : "—"
        text_box "Somme à payer à Psalmodia :    #{val}",
                 at: [ 6, cursor - 4 ],
                 style: (balance < 0 ? :bold : :normal),
                 width: bounds.width - 12
      end
    end

    # Balance = 0 case: override with neutral display
    if balance.zero?
      move_down 4
      font_size(9) { text "Solde : 0,00 € (réglé)", align: :center }
    end

    fill_color BLACK
    move_down 4
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

  # ---------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------

  def section_header(label)
    fill_color INDIGO
    fill_rectangle [ 0, cursor ], bounds.width, 16
    fill_color "FFFFFF"
    text_box label,
             at: [ 4, cursor - 3 ],
             size: 8,
             style: :bold,
             width: bounds.width - 8
    fill_color BLACK
    move_down 20
  end

  def two_col_row(label, amount_cents, bold: false)
    style = bold ? :bold : :normal
    amount_str = format_euros(amount_cents)
    col_widths = [ bounds.width - 80, 80 ]
    table(
      [ [ label, amount_str ] ],
      width: bounds.width,
      column_widths: col_widths,
      cell_style: {
        borders: [],
        size: 9,
        font_style: style,
        padding: [ 2, 2, 2, 2 ]
      }
    )
  end

  def advances_table(records)
    rows = records.map do |a|
      [ a.date.strftime("%d/%m/%Y"), format_euros(a.amount_cents), a.comment.to_s ]
    end
    table(
      rows,
      width: bounds.width,
      column_widths: [ 80, 80, bounds.width - 160 ],
      cell_style: { size: 9, borders: [ :bottom ], border_color: RULE, padding: [ 3, 2, 3, 2 ] },
      row_colors: [ "FFFFFF", "F9FAFB" ]
    )
  end

  def payments_table(records)
    rows = records.map do |p|
      [ p.date.strftime("%d/%m/%Y"), format_euros(p.amount_cents), p.comment.to_s ]
    end
    table(
      rows,
      width: bounds.width,
      column_widths: [ 80, 80, bounds.width - 160 ],
      cell_style: { size: 9, borders: [ :bottom ], border_color: RULE, padding: [ 3, 2, 3, 2 ] },
      row_colors: [ "FFFFFF", "F9FAFB" ]
    )
  end

  def format_euros(cents)
    return "—" if cents.nil?
    "#{"%.2f" % (cents / 100.0)}".gsub(".", ",") + " €"
  end

  def format_rate(cents_per_km)
    "#{"%.2f" % (cents_per_km / 100.0)}".gsub(".", ",")
  end

  def mm(val)
    val * 2.8346
  end
end
