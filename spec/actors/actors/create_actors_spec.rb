require "rails_helper"

RSpec.describe Actors::CreateStaffProfile do
  let(:edition) { create(:edition) }
  let(:person)  { create(:person) }

  context "linked to an existing person" do
    subject(:result) do
      described_class.call(
        edition:              edition,
        person:               person,
        staff_profile_params: { transport_mode: "Voiture", km_traveled: 100 }
      )
    end

    it "succeeds" do
      expect(result).to be_success
    end

    it "creates a StaffProfile" do
      expect { result }.to change(StaffProfile, :count).by(1)
    end

    it "auto-assigns dossier_number" do
      expect(result.staff_profile.dossier_number).to eq(1)
    end

    it "sets context.staff_profile" do
      expect(result.staff_profile).to be_a(StaffProfile)
    end

    it "links the person" do
      expect(result.staff_profile.person).to eq(person)
    end
  end

  context "direct entry without a person" do
    subject(:result) do
      described_class.call(
        edition:              edition,
        person:               nil,
        staff_profile_params: { first_name: "Marie", last_name: "Dupont", email: "marie@example.test" }
      )
    end

    it "succeeds" do
      expect(result).to be_success
    end

    it "creates a StaffProfile without a linked person" do
      expect(result.staff_profile.person).to be_nil
    end

    it "stores the direct name fields" do
      sp = result.staff_profile
      expect(sp.first_name).to eq("Marie")
      expect(sp.last_name).to eq("Dupont")
    end

    it "exposes full_name from direct fields" do
      expect(result.staff_profile.full_name).to eq("Marie Dupont")
    end
  end

  context "failure: neither person nor direct name" do
    it "fails with a validation error" do
      result = described_class.call(
        edition:              edition,
        person:               nil,
        staff_profile_params: {}
      )
      expect(result).to be_failure
      expect(result.error).to be_present
    end
  end
end

RSpec.describe Actors::CreateEdition do
  let(:params) do
    {
      name:       "Psalmodia 2027",
      year:       2027,
      start_date: "2027-07-01",
      end_date:   "2027-07-15"
    }
  end

  it "succeeds and creates an edition" do
    result = described_class.call(edition_params: params)
    expect(result).to be_success
    expect(result.edition).to be_a(Edition)
    expect(result.edition.year).to eq(2027)
  end

  it "fails when validation fails" do
    result = described_class.call(edition_params: params.merge(name: ""))
    expect(result).to be_failure
    expect(result.error).to be_present
  end
end
