require "rails_helper"

RSpec.describe Actors::UpdateStaffField do
  let(:staff_profile) { create(:staff_profile) }

  context "with an allowed field" do
    it "updates a cents field" do
      result = described_class.call(staff_profile: staff_profile, field: "allowance_cents", value: "150")
      expect(result).to be_success
      expect(staff_profile.reload.allowance_cents).to eq(150)
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
