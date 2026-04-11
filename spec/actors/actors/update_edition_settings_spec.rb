require "rails_helper"

RSpec.describe Actors::UpdateEditionSettings do
  let(:edition) { create(:edition) }

  context "with an allowed field" do
    it "updates name" do
      result = described_class.call(edition: edition, field: "name", value: "Psalmodia 2027")
      expect(result).to be_success
      expect(edition.reload.name).to eq("Psalmodia 2027")
    end

    it "updates km_rate_cents" do
      result = described_class.call(edition: edition, field: "km_rate_cents", value: "40")
      expect(result).to be_success
      expect(edition.reload.km_rate_cents).to eq(40)
    end
  end

  context "with a disallowed field" do
    it "fails with an error" do
      result = described_class.call(edition: edition, field: "id", value: "99")
      expect(result).to be_failure
      expect(result.error).to eq("Champ non autorisé")
    end
  end

  context "when validation fails" do
    it "fails with the model error" do
      result = described_class.call(edition: edition, field: "name", value: "")
      expect(result).to be_failure
      expect(result.error).to be_present
    end
  end
end
