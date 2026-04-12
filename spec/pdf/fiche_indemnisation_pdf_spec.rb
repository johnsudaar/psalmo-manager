require "rails_helper"
require "pdf/reader"

RSpec.describe FicheIndemnisationPdf do
  let(:edition) { create(:edition, year: 2026, km_rate_cents: 33) }
  let(:person)  { create(:person, first_name: "Alice", last_name: "Martin") }
  let(:staff_profile) do
    create(:staff_profile,
      person:                            person,
      edition:                           edition,
      allowance_cents:                   20000,
      km_traveled:                       150,
      supplies_cost_cents:               4500,
      accommodation_cost_cents:          0,
      meals_cost_cents:                  0,
      tickets_cost_cents:                0,
      member_uncovered_accommodation_cents: 0,
      member_uncovered_meals_cents:      0,
      member_uncovered_tickets_cents:    0,
      member_covered_tickets_cents:      0)
  end

  subject(:pdf_bytes) { described_class.new(staff_profile).render }

  def pdf_text
    reader = PDF::Reader.new(StringIO.new(pdf_bytes))
    reader.pages.map(&:text).join(" ")
  end

  it "renders a non-empty PDF binary" do
    expect(pdf_bytes).to be_a(String)
    expect(pdf_bytes.bytesize).to be > 0
    expect(pdf_bytes[0..3]).to eq("%PDF")
  end

  it "includes the association name" do
    expect(pdf_text).to include("PSALMODIA")
  end

  it "includes the edition year" do
    expect(pdf_text).to include("2026")
  end

  it "includes the staff member's name" do
    expect(pdf_text).to include("Martin")
    expect(pdf_text).to include("Alice")
  end

  it "includes the dossier number" do
    expect(pdf_text).to include(staff_profile.dossier_number.to_s)
  end

  it "includes the indemnités amount" do
    expect(pdf_text).to include("200,00")
  end

  it "includes the fiche d'indemnisation title" do
    expect(pdf_text).to include("INDEMNISATION")
  end

  context "with advances and payments" do
    before do
      create(:staff_advance, staff_profile: staff_profile, amount_cents: 5000, date: Date.new(2026, 3, 15))
      create(:staff_payment, staff_profile: staff_profile, amount_cents: 10000, date: Date.new(2026, 7, 1))
    end

    let(:staff_profile_with_records) do
      StaffProfile.includes(:person, :edition, :staff_advances, :staff_payments).find(staff_profile.id)
    end

    subject(:pdf_bytes) { described_class.new(staff_profile_with_records).render }

    it "includes advance amount" do
      expect(pdf_text).to include("50,00")
    end

    it "includes payment amount" do
      expect(pdf_text).to include("100,00")
    end
  end

  context "with no advances or payments" do
    it "still renders successfully" do
      expect { pdf_bytes }.not_to raise_error
    end

    it "includes zero total for advances section" do
      # Section acomptes total should show 0,00
      expect(pdf_text).to include("0,00")
    end
  end

  context "with km rate override" do
    let(:staff_profile) do
      create(:staff_profile,
        person:               person,
        edition:              edition,
        km_traveled:          200,
        km_rate_override_cents: 40,
        allowance_cents:      0,
        supplies_cost_cents:  0)
    end

    it "renders successfully with override km rate" do
      expect { pdf_bytes }.not_to raise_error
      expect(pdf_text).to include("200")
    end
  end
end
