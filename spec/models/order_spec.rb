require "rails_helper"

RSpec.describe Order, type: :model do
  subject(:order) { build(:order) }

  describe "associations" do
    it { is_expected.to belong_to(:edition) }
    it { is_expected.to belong_to(:payer).class_name("Person").optional }
    it { is_expected.to have_many(:registrations).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:helloasso_order_id) }
    it { is_expected.to validate_uniqueness_of(:helloasso_order_id) }
    it { is_expected.to validate_presence_of(:order_date) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, confirmed: 1, cancelled: 2, refunded: 3) }
  end
end
