class StaffProfile < ApplicationRecord
  has_paper_trail skip: [ :updated_at ], skip_unchanged: true

  belongs_to :person
  belongs_to :edition
  has_many :staff_advances, dependent: :destroy
  has_many :staff_payments, dependent: :destroy

  validates :dossier_number, presence: true, uniqueness: { scope: :edition_id }

  before_validation :assign_dossier_number, on: :create

  def effective_km_rate_cents
    km_rate_override_cents || edition.km_rate_cents
  end

  def travel_allowance_cents
    (km_traveled * effective_km_rate_cents).round
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
    amount_owed_to_instructor_cents - total_advances_cents - total_payments_cents
  end

  def psalmodia_owes?
    balance_cents > 0
  end

  def instructor_owes?
    balance_cents < 0
  end

  private

  def assign_dossier_number
    return unless edition

    max = edition.staff_profiles.maximum(:dossier_number) || 0
    self.dossier_number = max + 1
  end
end
