require "rails_helper"

RSpec.describe Actors::UpdateStaffField do
  let(:staff_profile) { create(:staff_profile) }

  context "with an allowed field" do
    it "updates a cents field from a human decimal euro value" do
      result = described_class.call(staff_profile: staff_profile, field: "allowance_cents", value: "150,00")
      expect(result).to be_success
      expect(staff_profile.reload.allowance_cents).to eq(15_000)
    end

    it "clears the km rate override when submitted blank" do
      staff_profile.update!(km_rate_override_cents: 41)

      result = described_class.call(staff_profile: staff_profile, field: "km_rate_override_cents", value: "")

      expect(result).to be_success
      expect(staff_profile.reload.km_rate_override_cents).to be_nil
    end

    it "clears the travel override when submitted blank" do
      staff_profile.update!(travel_override_cents: 4550)

      result = described_class.call(staff_profile: staff_profile, field: "travel_override_cents", value: "")

      expect(result).to be_success
      expect(staff_profile.reload.travel_override_cents).to be_nil
    end

    it "resets traveled kilometers to zero when submitted blank" do
      staff_profile.update!(km_traveled: 125)

      result = described_class.call(staff_profile: staff_profile, field: "km_traveled", value: "")

      expect(result).to be_success
      expect(staff_profile.reload.km_traveled).to eq(0)
    end

    it "updates a string field" do
      result = described_class.call(staff_profile: staff_profile, field: "transport_mode", value: "Train")
      expect(result).to be_success
      expect(staff_profile.reload.transport_mode).to eq("Train")
    end

    it "updates notes" do
      result = described_class.call(staff_profile: staff_profile, field: "notes", value: "Remarque importante")
      expect(result).to be_success
      expect(staff_profile.reload.notes).to eq("Remarque importante")
    end
  end

  context "with a disallowed field" do
    it "fails with an error" do
      result = described_class.call(staff_profile: staff_profile, field: "person_id", value: "99")
      expect(result).to be_failure
      expect(result.error).to eq("Champ non autorisé")
    end
  end
end
