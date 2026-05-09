require "rails_helper"

RSpec.describe Person, type: :model do
  subject(:person) { build(:person) }

  describe "associations" do
    it { is_expected.to have_many(:registrations).dependent(:destroy) }
    it { is_expected.to have_many(:orders).with_foreign_key(:payer_id).dependent(:nullify) }
    it { is_expected.to have_one(:staff_profile).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:first_name) }
  end

  describe "#full_name" do
    it "combines first and last name" do
      person.first_name = "Marie"
      person.last_name  = "Dupont"
      expect(person.full_name).to eq("Marie Dupont")
    end
  end

  describe "#age_on" do
    it "returns nil when date_of_birth is nil" do
      person.date_of_birth = nil
      expect(person.age_on(Date.today)).to be_nil
    end

    it "returns correct age before birthday in the year" do
      person.date_of_birth = Date.new(2000, 8, 1)
      expect(person.age_on(Date.new(2026, 7, 1))).to eq(25)
    end

    it "returns correct age on and after birthday in the year" do
      person.date_of_birth = Date.new(2000, 7, 1)
      expect(person.age_on(Date.new(2026, 7, 1))).to eq(26)
    end
  end
end
