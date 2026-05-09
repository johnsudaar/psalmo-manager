require "rails_helper"

RSpec.describe Workshop, type: :model do
  subject(:workshop) { build(:workshop) }

  describe "associations" do
    it { is_expected.to belong_to(:edition) }
    it { is_expected.to have_many(:registration_workshops).dependent(:destroy) }
    it { is_expected.to have_many(:registrations).through(:registration_workshops) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:time_slot) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:edition_id) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:time_slot).with_values(matin: 0, apres_midi: 1, journee: 2) }
  end

  describe "#fill_rate" do
    it "returns nil when capacity is nil" do
      workshop.capacity = nil
      expect(workshop.fill_rate).to be_nil
    end

    it "returns nil when capacity is zero" do
      workshop.capacity = 0
      expect(workshop.fill_rate).to be_nil
    end

    it "returns the percentage of registrations vs capacity" do
      workshop.save!
      edition = workshop.edition
      order = create(:order, edition: edition)
      3.times { create(:registration_workshop, workshop: workshop, registration: create(:registration, order: order, edition: edition)) }
      expect(workshop.fill_rate).to eq(15.0)
    end
  end

  describe "#full?" do
    it "returns false when capacity is nil" do
      workshop.capacity = nil
      expect(workshop.full?).to be false
    end

    it "returns true when registrations meet capacity" do
      workshop.capacity = 1
      workshop.save!
      edition = workshop.edition
      order = create(:order, edition: edition)
      create(:registration_workshop, workshop: workshop, registration: create(:registration, order: order, edition: edition))
      expect(workshop.full?).to be true
    end
  end
end
