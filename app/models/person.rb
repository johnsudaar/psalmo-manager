class Person < ApplicationRecord
  has_paper_trail skip: [ :updated_at ], skip_unchanged: true

  has_many :registrations, dependent: :destroy
  has_many :orders, foreign_key: :payer_id, dependent: :nullify
  has_one  :staff_profile, dependent: :destroy

  validates :last_name, :first_name, presence: true

  def full_name
    "#{first_name} #{last_name}"
  end

  def age_on(date)
    return nil unless date_of_birth
    years = date.year - date_of_birth.year
    years -= 1 if date < date_of_birth + years.years
    years
  end
end
