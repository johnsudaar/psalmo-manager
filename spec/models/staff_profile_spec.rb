require "rails_helper"

RSpec.describe StaffProfile, type: :model do
  subject(:profile) { build(:staff_profile) }

  describe "associations" do
    it { is_expected.to belong_to(:person).optional }
    it { is_expected.to belong_to(:edition) }
    it { is_expected.to have_many(:staff_advances).dependent(:destroy) }
    it { is_expected.to have_many(:staff_payments).dependent(:destroy) }
  end

  describe "validations" do
    it "is invalid without a dossier_number after save" do
      profile.save!
      profile.dossier_number = nil
      expect(profile).not_to be_valid
      expect(profile.errors[:dossier_number]).to be_present
    end

    it "does not allow two profiles with the same dossier_number in the same edition" do
      first = create(:staff_profile)
      duplicate = build(:staff_profile, edition: first.edition, dossier_number: first.dossier_number)
      # bypass the callback so we can test the uniqueness validation directly
      duplicate.instance_variable_set(:@skip_assign, true)
      allow(duplicate).to receive(:assign_dossier_number)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:dossier_number]).to be_present
    end
  end

  describe "before_create callback" do
    it "auto-assigns dossier_number" do
      profile.dossier_number = nil
      profile.save!
      expect(profile.dossier_number).to eq(1)
    end

    it "increments dossier_number per edition" do
      first = create(:staff_profile, edition: profile.edition)
      profile.save!
      expect(profile.dossier_number).to eq(first.dossier_number + 1)
    end
  end

  describe "#effective_km_rate_cents" do
    it "returns the edition rate when no override is set" do
      profile.km_rate_override_cents = nil
      expect(profile.effective_km_rate_cents).to eq(profile.edition.km_rate_cents)
    end

    it "returns the override rate when set" do
      profile.km_rate_override_cents = 41
      expect(profile.effective_km_rate_cents).to eq(41)
    end
  end

  describe "#travel_allowance_cents" do
    it "computes km × rate" do
      profile.km_traveled = 100
      profile.km_rate_override_cents = nil
      profile.edition.km_rate_cents = 33
      expect(profile.travel_allowance_cents).to eq(3300)
    end

    it "returns the raw override when present" do
      profile.travel_override_cents = 4550
      expect(profile.travel_allowance_cents).to eq(4550)
    end

    it "returns zero when km_traveled is nil" do
      profile.km_traveled = nil
      profile.km_rate_override_cents = nil
      profile.edition.km_rate_cents = 33

      expect(profile.travel_allowance_cents).to eq(0)
    end
  end

  describe "#total_to_pay_instructor_cents" do
    it "sums allowance, travel, and supplies" do
      profile.allowance_cents     = 20000
      profile.supplies_cost_cents = 4500
      profile.km_traveled         = 0
      expect(profile.total_to_pay_instructor_cents).to eq(24500)
    end
  end

  describe "#balance_cents" do
    it "is positive when Psalmodia owes the instructor" do
      profile.save!
      # owed = 20000 allowance + 150km*33 = 24950, minus zero payments
      expect(profile.balance_cents).to be > 0
    end

    it "decreases when a payment is recorded" do
      profile.save!
      balance_before = profile.balance_cents
      create(:staff_payment, staff_profile: profile, amount_cents: 5000)
      expect(profile.balance_cents).to eq(balance_before - 5000)
    end

    it "increases when an advance is recorded" do
      profile.save!
      balance_before = profile.balance_cents
      create(:staff_advance, staff_profile: profile, amount_cents: 1000)
      expect(profile.balance_cents).to eq(balance_before + 1000)
    end
  end

  describe "#psalmodia_owes?" do
    it "returns true when balance is positive" do
      profile.save!
      expect(profile.psalmodia_owes?).to be true
    end
  end
end
