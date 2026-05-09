class Workshop < ApplicationRecord
  has_paper_trail skip: [ :updated_at ], skip_unchanged: true

  belongs_to :edition
  has_many :registration_workshops, dependent: :destroy
  has_many :registrations, through: :registration_workshops

  enum :time_slot, { matin: 0, apres_midi: 1, journee: 2 }

  validates :name, :time_slot, presence: true
  validates :name, uniqueness: { scope: :edition_id }

  def fill_rate
    return nil if capacity.nil? || capacity.zero?
    (registrations.count.to_f / capacity * 100).round(1)
  end

  def full?
    capacity.present? && registrations.count >= capacity
  end
end
