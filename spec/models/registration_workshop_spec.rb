require "rails_helper"

RSpec.describe RegistrationWorkshop, type: :model do
  subject(:rw) { create(:registration_workshop) }

  describe "associations" do
    it { is_expected.to belong_to(:registration) }
    it { is_expected.to belong_to(:workshop) }
  end

  describe "validations" do
    it { is_expected.to validate_uniqueness_of(:registration_id).scoped_to(:workshop_id) }
  end
end
