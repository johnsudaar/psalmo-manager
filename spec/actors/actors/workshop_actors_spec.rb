require "rails_helper"

RSpec.describe Actors::CreateWorkshop do
  let(:edition) { create(:edition) }

  context "happy path" do
    subject(:result) do
      described_class.call(
        edition:         edition,
        workshop_params: { name: "CIRQUE", time_slot: :matin, capacity: 20 }
      )
    end

    it "succeeds" do
      expect(result).to be_success
    end

    it "creates a workshop" do
      expect { result }.to change(Workshop, :count).by(1)
    end

    it "sets context.workshop" do
      expect(result.workshop).to be_a(Workshop)
    end

    it "scopes the workshop to the edition" do
      expect(result.workshop.edition).to eq(edition)
    end
  end

  context "when validation fails" do
    it "fails with an error" do
      result = described_class.call(edition: edition, workshop_params: { name: "", time_slot: :matin })
      expect(result).to be_failure
      expect(result.error).to be_present
    end
  end
end

RSpec.describe Actors::UpdateWorkshop do
  let(:workshop) { create(:workshop) }

  it "updates the workshop" do
    result = described_class.call(workshop: workshop, workshop_params: { name: "NOUVEAU NOM" })
    expect(result).to be_success
    expect(workshop.reload.name).to eq("NOUVEAU NOM")
  end

  it "fails when validation fails" do
    result = described_class.call(workshop: workshop, workshop_params: { name: "" })
    expect(result).to be_failure
  end
end

RSpec.describe Actors::DestroyWorkshop do
  context "when no registrations" do
    let!(:workshop) { create(:workshop) }

    it "destroys the workshop" do
      expect { described_class.call(workshop: workshop) }.to change(Workshop, :count).by(-1)
    end

    it "succeeds" do
      expect(described_class.call(workshop: workshop)).to be_success
    end
  end

  context "when workshop has registrations" do
    let!(:rw)      { create(:registration_workshop) }
    let(:workshop) { rw.workshop }

    it "fails" do
      result = described_class.call(workshop: workshop)
      expect(result).to be_failure
      expect(result.error).to eq("Impossible de supprimer un atelier avec des inscriptions.")
    end

    it "does not destroy the workshop" do
      expect { described_class.call(workshop: workshop) }.not_to change(Workshop, :count)
    end
  end
end
