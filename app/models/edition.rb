class Edition < ApplicationRecord
  has_paper_trail skip: [ :updated_at ], skip_unchanged: true

  has_many :workshops, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :registrations, through: :orders
  has_many :staff_profiles, dependent: :destroy

  validates :name, :year, :start_date, :end_date, presence: true
  validates :year, uniqueness: true
  validates :km_rate_cents, numericality: { greater_than: 0 }

  scope :ordered, -> { order(year: :desc) }

  def current?
    Edition.order(year: :desc).first == self
  end
end
