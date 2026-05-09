class StaffAdvance < ApplicationRecord
  has_paper_trail skip: [ :updated_at ], skip_unchanged: true

  belongs_to :staff_profile

  validates :date, :amount_cents, presence: true
end
