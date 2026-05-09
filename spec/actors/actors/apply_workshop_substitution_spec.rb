require "rails_helper"

RSpec.describe Actors::ApplyWorkshopSubstitution do
  let(:edition)      { create(:edition) }
  let(:other_edition) { create(:edition) }
  let(:workshop_a)   { create(:workshop, edition: edition, time_slot: :matin) }
  let(:workshop_b)   { create(:workshop, edition: edition, time_slot: :matin) }
  let(:workshop_c)   { create(:workshop, edition: edition, time_slot: :apres_midi) }
  let(:workshop_d)   { create(:workshop, edition: edition, time_slot: :journee) }
  let(:registration) { create(:registration, edition: edition) }

  before { create(:registration_workshop, registration: registration, workshop: workshop_a) }

  context "happy path" do
    subject(:result) do
      described_class.call(registration: registration, workshop_ids: [ workshop_b.id ])
    end

    it "succeeds" do
      expect(result).to be_success
    end

    it "creates a new RegistrationWorkshop with is_override: true" do
      result
      rw = registration.registration_workshops.find_by(workshop: workshop_b)
      expect(rw).to be_present
      expect(rw.is_override).to be(true)
      expect(registration.reload.has_workshop_override).to be(true)
      expect(registration.workshop_override_backup).to eq([
        {
          "workshop_id" => workshop_a.id,
          "price_paid_cents" => 0
        }
      ])
    end

    it "destroys the existing workshop for the same time slot" do
      result
      expect(registration.registration_workshops.find_by(workshop: workshop_a)).to be_nil
    end

    it "sets context.registration_workshops" do
      expect(result.registration_workshops).to all(be_a(RegistrationWorkshop))
    end
  end

  context "when adding a second workshop on another time slot" do
    subject(:result) do
      described_class.call(registration: registration, workshop_ids: [ workshop_a.id, workshop_c.id ])
    end

    it "keeps both workshops" do
      result

      expect(registration.registration_workshops.reload.pluck(:workshop_id)).to match_array([ workshop_a.id, workshop_c.id ])
    end
  end

  context "when removing all workshops" do
    subject(:result) do
      described_class.call(registration: registration, workshop_ids: [])
    end

    it "removes every workshop from the registration" do
      result

      expect(registration.registration_workshops.reload).to be_empty
      expect(registration.reload.has_workshop_override).to be(true)
    end
  end

  context "when selecting more than two workshops" do
    let(:workshop_e) { create(:workshop, edition: edition, time_slot: :apres_midi, name: "AUTRE") }

    subject(:result) do
      described_class.call(registration: registration, workshop_ids: [ workshop_a.id, workshop_c.id, workshop_e.id ])
    end

    it "fails" do
      expect(result).to be_failure
    end

    it "returns a validation error" do
      expect(result.error).to eq("Une inscription ne peut pas avoir plus de 2 ateliers")
    end
  end

  context "when updating an existing override" do
    before do
      described_class.call(registration: registration, workshop_ids: [ workshop_c.id ])
    end

    it "keeps the original backup instead of replacing it" do
      described_class.call(registration: registration, workshop_ids: [ workshop_a.id ])

      expect(registration.reload.workshop_override_backup).to eq([
        {
          "workshop_id" => workshop_a.id,
          "price_paid_cents" => 0
        }
      ])
    end
  end

  context "when selecting two workshops on the same time slot" do
    subject(:result) do
      described_class.call(registration: registration, workshop_ids: [ workshop_a.id, workshop_b.id ])
    end

    it "fails" do
      expect(result).to be_failure
    end

    it "returns a validation error" do
      expect(result.error).to eq("Une inscription ne peut pas avoir deux ateliers sur le même créneau")
    end
  end

  context "when combining a journee workshop with another workshop" do
    subject(:result) do
      described_class.call(registration: registration, workshop_ids: [ workshop_d.id, workshop_c.id ])
    end

    it "fails" do
      expect(result).to be_failure
    end

    it "returns a validation error" do
      expect(result.error).to eq("Un atelier journée ne peut pas être combiné avec un autre atelier")
    end
  end

  context "when workshop belongs to a different edition" do
    let(:cross_edition_workshop) { create(:workshop, edition: other_edition, time_slot: :matin) }

    subject(:result) do
      described_class.call(registration: registration, workshop_ids: [ cross_edition_workshop.id ])
    end

    it "fails" do
      expect(result).to be_failure
    end

    it "sets context.error" do
      expect(result.error).to eq("Atelier hors édition")
    end
  end
end
