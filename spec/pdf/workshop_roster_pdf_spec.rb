require "rails_helper"
require "pdf/reader"

RSpec.describe WorkshopRosterPdf do
  let(:edition)  { create(:edition, year: 2026) }
  let(:workshop) { create(:workshop, edition: edition, name: "Chant choral", time_slot: :matin, capacity: 20) }
  let(:person1)  { create(:person, first_name: "Marie", last_name: "Dupont") }
  let(:person2)  { create(:person, first_name: "Pierre", last_name: "Bernard") }
  let(:order)    { create(:order, edition: edition) }

  subject(:pdf_bytes) { described_class.new(workshop).render }

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

  it "includes the workshop name" do
    expect(pdf_text).to include("Chant choral")
  end

  it "includes the time slot label" do
    expect(pdf_text).to include("Matin")
  end

  context "with participants" do
    before do
      reg1 = create(:registration, person: person1, order: order, edition: edition, age_category: :adulte)
      reg2 = create(:registration, person: person2, order: order, edition: edition, age_category: :enfant)
      create(:registration_workshop, registration: reg1, workshop: workshop)
      create(:registration_workshop, registration: reg2, workshop: workshop)
    end

    let(:workshop_loaded) do
      Workshop.includes(registrations: :person).find(workshop.id)
    end

    subject(:pdf_bytes) { described_class.new(workshop_loaded).render }

    it "includes participant last names" do
      expect(pdf_text).to include("Dupont")
      expect(pdf_text).to include("Bernard")
    end

    it "includes participant first names" do
      expect(pdf_text).to include("Marie")
      expect(pdf_text).to include("Pierre")
    end

    it "includes age category labels" do
      expect(pdf_text).to include("Adulte")
      expect(pdf_text).to include("Enfant")
    end
  end

  context "with no participants" do
    it "renders successfully without error" do
      expect { pdf_bytes }.not_to raise_error
    end

    it "includes a no-participants message" do
      expect(pdf_text).to include("Aucun")
    end
  end

  context "with apres_midi time slot" do
    let(:workshop) { create(:workshop, edition: edition, name: "Percussion", time_slot: :apres_midi) }

    it "shows correct time slot label" do
      expect(pdf_text).to include("Après-midi")
    end
  end
end
