class Registration < ApplicationRecord
  has_paper_trail skip: [ :updated_at ], skip_unchanged: true

  belongs_to :order
  belongs_to :person
  belongs_to :edition
  has_many :registration_workshops, dependent: :destroy
  has_many :workshops, through: :registration_workshops

  enum :age_category, { enfant: 0, adulte: 1 }

  validates :helloasso_ticket_id, presence: true, uniqueness: true
  validates :age_category, presence: true

  scope :for_stats, -> { where(excluded_from_stats: false) }
  scope :unaccompanied_minors, -> { where(is_unaccompanied_minor: true) }
  scope :with_conflicts, -> { where(has_conflict: true) }

  def actual_price_cents
    ticket_price_cents - discount_cents
  end
end
