class StaffProfile < ApplicationRecord
  has_paper_trail skip: [ :updated_at ], skip_unchanged: true

  belongs_to :person, optional: true
  belongs_to :edition
  has_many :staff_advances, dependent: :destroy
  has_many :staff_payments, dependent: :destroy

  validates :dossier_number, presence: true, uniqueness: { scope: :edition_id }
  validates :last_name, :first_name, presence: true, unless: -> { person.present? }
  validate :person_or_direct_fields

  before_validation :assign_dossier_number, on: :create

  # Returns the display name whether the staff is linked to a Person or entered directly.
  def full_name
    if person
      person.full_name
    else
      "#{first_name} #{last_name}".strip
    end
  end

  def display_email
    person&.email || email
  end

  def display_phone
    person&.phone || phone
  end

  def effective_allowance_label
    allowance_label.presence || edition.allowance_label_options.first || "Frais atelier"
  end

  def effective_km_rate_cents
    km_rate_override_cents || edition.km_rate_cents
  end

  def travel_allowance_cents
    return travel_override_cents if travel_override_cents.present?

    ((km_traveled || 0) * effective_km_rate_cents).round
  end

  def total_to_pay_instructor_cents
    allowance_cents + travel_allowance_cents + supplies_cost_cents
  end

  def total_psalmodia_covers_cents
    accommodation_cost_cents + meals_cost_cents + tickets_cost_cents
  end

  def total_member_uncovered_cents
    member_uncovered_accommodation_cents +
      member_uncovered_meals_cents +
      member_uncovered_tickets_cents
  end

  def total_member_covered_cents
    member_covered_tickets_cents
  end

  def amount_owed_to_instructor_cents
    total_to_pay_instructor_cents +
      total_psalmodia_covers_cents -
      total_member_uncovered_cents +
      total_member_covered_cents
  end

  def total_advances_cents
    staff_advances.sum(:amount_cents)
  end

  def total_payments_cents
    staff_payments.sum(:amount_cents)
  end

  def balance_cents
    amount_owed_to_instructor_cents + total_advances_cents - total_payments_cents
  end

  def psalmodia_owes?
    balance_cents > 0
  end

  def instructor_owes?
    balance_cents < 0
  end

  private

  def person_or_direct_fields
    return if person.present? || (first_name.present? && last_name.present?)

    errors.add(:base, "Un animateur doit être lié à une personne ou avoir un nom et prénom saisis directement")
  end

  def assign_dossier_number
    return unless edition

    max = edition.staff_profiles.maximum(:dossier_number) || 0
    self.dossier_number = max + 1
  end
end
