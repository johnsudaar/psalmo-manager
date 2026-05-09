require "rails_helper"

RSpec.describe Actors::UpdateRegistrationOverride do
  let(:registration) { create(:registration) }

  context "excluded_from_stats" do
    it "updates the field to true" do
      result = described_class.call(registration: registration, field: "excluded_from_stats", value: "1")
      expect(result).to be_success
      expect(registration.reload.excluded_from_stats).to be(true)
    end

    it "updates the field to false" do
      registration.update!(excluded_from_stats: true)
      result = described_class.call(registration: registration, field: "excluded_from_stats", value: "0")
      expect(result).to be_success
      expect(registration.reload.excluded_from_stats).to be(false)
    end
  end

  context "is_unaccompanied_minor" do
    it "updates the field" do
      result = described_class.call(registration: registration, field: "is_unaccompanied_minor", value: "true")
      expect(result).to be_success
      expect(registration.reload.is_unaccompanied_minor).to be(true)
    end
  end

  context "responsible_person_note" do
    it "updates the note" do
      result = described_class.call(registration: registration, field: "responsible_person_note", value: "Responsabilité Marie")
      expect(result).to be_success
      expect(registration.reload.responsible_person_note).to eq("Responsabilité Marie")
    end
  end

  context "when field is not in the allowlist" do
    it "fails with an error" do
      result = described_class.call(registration: registration, field: "helloasso_ticket_id", value: "FAKE")
      expect(result).to be_failure
      expect(result.error).to eq("Champ non autorisé")
    end

    it "does not modify the record" do
      original = registration.helloasso_ticket_id
      described_class.call(registration: registration, field: "helloasso_ticket_id", value: "FAKE")
      expect(registration.reload.helloasso_ticket_id).to eq(original)
    end
  end
end
