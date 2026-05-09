require "rails_helper"

RSpec.describe Registration, type: :model do
  subject(:registration) { build(:registration) }

  describe "associations" do
    it { is_expected.to belong_to(:order) }
    it { is_expected.to belong_to(:person) }
    it { is_expected.to belong_to(:edition) }
    it { is_expected.to have_many(:registration_workshops).dependent(:destroy) }
    it { is_expected.to have_many(:workshops).through(:registration_workshops) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:helloasso_ticket_id) }
    it { is_expected.to validate_uniqueness_of(:helloasso_ticket_id) }
    it { is_expected.to validate_presence_of(:age_category) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:age_category).with_values(enfant: 0, adulte: 1) }
  end

  describe "scopes" do
    let!(:included) { create(:registration, excluded_from_stats: false) }
    let!(:excluded) { create(:registration, excluded_from_stats: true) }
    let!(:minor)    { create(:registration, is_unaccompanied_minor: true) }
    let!(:conflict) { create(:registration, has_conflict: true) }

    it ".for_stats excludes excluded registrations" do
      expect(Registration.for_stats).to include(included)
      expect(Registration.for_stats).not_to include(excluded)
    end

    it ".unaccompanied_minors returns only minors" do
      expect(Registration.unaccompanied_minors).to include(minor)
      expect(Registration.unaccompanied_minors).not_to include(included)
    end

    it ".with_conflicts returns only conflicted registrations" do
      expect(Registration.with_conflicts).to include(conflict)
      expect(Registration.with_conflicts).not_to include(included)
    end
  end

  describe "#actual_price_cents" do
    it "returns ticket price minus discount" do
      registration.ticket_price_cents = 10000
      registration.discount_cents     = 2000
      expect(registration.actual_price_cents).to eq(8000)
    end
  end
end
