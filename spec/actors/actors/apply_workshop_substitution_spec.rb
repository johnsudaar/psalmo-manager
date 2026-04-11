require "rails_helper"

RSpec.describe Actors::ApplyWorkshopSubstitution do
  let(:edition)      { create(:edition) }
  let(:other_edition) { create(:edition) }
  let(:workshop_a)   { create(:workshop, edition: edition, time_slot: :matin) }
  let(:workshop_b)   { create(:workshop, edition: edition, time_slot: :matin) }
  let(:registration) { create(:registration, edition: edition) }

  before { create(:registration_workshop, registration: registration, workshop: workshop_a) }

  context "happy path" do
    subject(:result) do
      described_class.call(registration: registration, workshop: workshop_b)
    end

    it "succeeds" do
      expect(result).to be_success
    end

    it "creates a new RegistrationWorkshop with is_override: true" do
      result
      rw = registration.registration_workshops.find_by(workshop: workshop_b)
      expect(rw).to be_present
      expect(rw.is_override).to be(true)
    end

    it "destroys the existing workshop for the same time slot" do
      result
      expect(registration.registration_workshops.find_by(workshop: workshop_a)).to be_nil
    end

    it "sets context.registration_workshop" do
      expect(result.registration_workshop).to be_a(RegistrationWorkshop)
    end
  end

  context "when workshop belongs to a different edition" do
    let(:cross_edition_workshop) { create(:workshop, edition: other_edition, time_slot: :matin) }

    subject(:result) do
      described_class.call(registration: registration, workshop: cross_edition_workshop)
    end

    it "fails" do
      expect(result).to be_failure
    end

    it "sets context.error" do
      expect(result.error).to eq("Atelier hors édition")
    end
  end
end
