require "rails_helper"

RSpec.describe Actors::CreateStaffProfile do
  let(:edition) { create(:edition) }
  let(:person)  { create(:person) }

  context "happy path" do
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
