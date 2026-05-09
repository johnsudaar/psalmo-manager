require "rails_helper"

RSpec.describe StaffPayment, type: :model do
  subject(:payment) { build(:staff_payment) }

  describe "associations" do
    it { is_expected.to belong_to(:staff_profile) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:amount_cents) }
  end
end
