class RegistrationWorkshop < ApplicationRecord
  has_paper_trail skip: [ :updated_at ], skip_unchanged: true

  belongs_to :registration
  belongs_to :workshop

  validates :registration_id, uniqueness: { scope: :workshop_id }
end
