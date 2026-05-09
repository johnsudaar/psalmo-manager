require "rails_helper"

RSpec.describe Importers::StaffCsvImporter do
  let(:csv_path) { Rails.root.join("spec/fixtures/csv/staff_recap_sample.csv").to_s }
  let(:edition)  { create(:edition, year: 2026, start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 15)) }

  subject(:result) { described_class.new(csv_path: csv_path, edition_id: edition.id).call }

  describe "#call" do
    it "returns a result hash" do
      expect(result).to include(:created, :updated, :errors)
    end

    it "creates one StaffProfile per data row" do
      expect { result }.to change(StaffProfile, :count).by(3)
    end

    it "creates a Person for each staff member" do
      expect { result }.to change(Person, :count).by(3)
    end

    it "sets internal_id on the profile" do
      result
      alice = Person.find_by(last_name: "Durand", first_name: "Alice")
      profile = StaffProfile.find_by(person: alice, edition: edition)
      expect(profile.internal_id).to eq("001_")
    end

    it "sets transport_mode" do
      result
      alice = Person.find_by(last_name: "Durand", first_name: "Alice")
      expect(StaffProfile.find_by(person: alice, edition: edition).transport_mode).to eq("Voiture")
    end

    it "sets km_traveled" do
      result
      alice = Person.find_by(last_name: "Durand", first_name: "Alice")
      expect(StaffProfile.find_by(person: alice, edition: edition).km_traveled).to eq(120.0)
    end

    it "converts allowance to cents" do
      result
      alice = Person.find_by(last_name: "Durand", first_name: "Alice")
      expect(StaffProfile.find_by(person: alice, edition: edition).allowance_cents).to eq(5000)
    end

    it "converts supplies_cost to cents" do
      result
      alice = Person.find_by(last_name: "Durand", first_name: "Alice")
      expect(StaffProfile.find_by(person: alice, edition: edition).supplies_cost_cents).to eq(3000)
    end

    it "converts accommodation_cost to cents" do
      result
      alice = Person.find_by(last_name: "Durand", first_name: "Alice")
      expect(StaffProfile.find_by(person: alice, edition: edition).accommodation_cost_cents).to eq(20000)
    end

    it "sets member_uncovered_accommodation_cents" do
      result
      marc = Person.find_by(last_name: "Bernard", first_name: "Marc")
      expect(StaffProfile.find_by(person: marc, edition: edition).member_uncovered_accommodation_cents).to eq(2000)
    end

    it "sets member_covered_tickets_cents" do
      result
      sophie = Person.find_by(last_name: "Petit", first_name: "Sophie")
      expect(StaffProfile.find_by(person: sophie, edition: edition).member_covered_tickets_cents).to eq(1000)
    end

    it "sets allowance_label" do
      result
      alice = Person.find_by(last_name: "Durand", first_name: "Alice")
      expect(StaffProfile.find_by(person: alice, edition: edition).allowance_label).to eq("Indemnité cirque")
    end

    it "sets notes" do
      result
      alice = Person.find_by(last_name: "Durand", first_name: "Alice")
      expect(StaffProfile.find_by(person: alice, edition: edition).notes).to eq("RAS")
    end

    it "assigns a dossier_number automatically" do
      result
      profiles = StaffProfile.where(edition: edition).order(:dossier_number)
      expect(profiles.map(&:dossier_number)).to eq([ 1, 2, 3 ])
    end

    it "reports created count" do
      expect(result[:created]).to eq(3)
      expect(result[:updated]).to eq(0)
      expect(result[:errors]).to be_empty
    end

    context "idempotency" do
      it "does not create duplicate StaffProfiles on second run" do
        described_class.new(csv_path: csv_path, edition_id: edition.id).call
        expect {
          described_class.new(csv_path: csv_path, edition_id: edition.id).call
        }.not_to change(StaffProfile, :count)
      end

      it "reports updated count on second run" do
        described_class.new(csv_path: csv_path, edition_id: edition.id).call
        result2 = described_class.new(csv_path: csv_path, edition_id: edition.id).call
        expect(result2[:updated]).to eq(3)
        expect(result2[:created]).to eq(0)
      end

      it "does not create duplicate Person records" do
        described_class.new(csv_path: csv_path, edition_id: edition.id).call
        expect {
          described_class.new(csv_path: csv_path, edition_id: edition.id).call
        }.not_to change(Person, :count)
      end
    end

    context "when a row is blank" do
      it "skips rows with no name" do
        csv = Tempfile.new([ "staff", ".csv" ])
        csv.write("Identifiant,Nom,Prénom,Mode de déplacement,KM Parcourus,Indemnités,Frais de déplacement,Frais fournitures atelier,Total (frais à payer),Hébergement (pris en charge),Repas (pris en charge),Billets/Ateliers (pris en charge),Total (animateur pris en charge),Hébergement non pris en charge,Repas non pris en charge,Billets non pris en charge,Total membres à payer,Billets membres pris en charge,Total membres pris en charge,À payer à l'animateur,Montant reçu de l'animateur,Solde,Coût animateur,Nom indemnité,Commentaires\n")
        csv.write(",,,,,,,,,,,,,,,,,,,,,,,,\n")  # completely blank row
        csv.write("004_,Test,User,Vélo,0,0,0,0,,0,0,0,,0,0,0,,0,,,,,,, \n")
        csv.close

        expect {
          described_class.new(csv_path: csv.path, edition_id: edition.id).call
        }.to change(StaffProfile, :count).by(1)

        csv.unlink
      end
    end
  end
end

RSpec.describe Importers::VersementsCsvImporter do
  let(:csv_path) { Rails.root.join("spec/fixtures/csv/versements_sample.csv").to_s }
  let(:edition)  { create(:edition, year: 2026, start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 15)) }

  # Profiles must exist before versements can be imported
  before do
    Importers::StaffCsvImporter.new(
      csv_path:   Rails.root.join("spec/fixtures/csv/staff_recap_sample.csv").to_s,
      edition_id: edition.id
    ).call
  end

  subject(:result) { described_class.new(csv_path: csv_path, edition_id: edition.id).call }

  describe "#call" do
    it "returns a result hash" do
      expect(result).to include(:advances, :payments, :errors)
    end

    it "creates StaffAdvance records when De matches a profile" do
      expect { result }.to change(StaffAdvance, :count).by(2)
    end

    it "creates StaffPayment records when A matches a profile" do
      expect { result }.to change(StaffPayment, :count).by(2)
    end

    it "associates advances with the correct profile" do
      result
      alice   = Person.find_by(last_name: "Durand", first_name: "Alice")
      profile = StaffProfile.find_by(person: alice, edition: edition)
      expect(profile.staff_advances.sum(:amount_cents)).to eq(15000) # 100 + 50 euros
    end

    it "associates payments with the correct profile" do
      result
      marc    = Person.find_by(last_name: "Bernard", first_name: "Marc")
      profile = StaffProfile.find_by(person: marc, edition: edition)
      expect(profile.staff_payments.sum(:amount_cents)).to eq(20000) # 200 euros
    end

    it "stores the comment on the record" do
      result
      alice   = Person.find_by(last_name: "Durand", first_name: "Alice")
      profile = StaffProfile.find_by(person: alice, edition: edition)
      advance = profile.staff_advances.order(:date).first
      expect(advance.comment).to eq("Acompte versé")
    end

    it "parses the date correctly" do
      result
      alice   = Person.find_by(last_name: "Durand", first_name: "Alice")
      profile = StaffProfile.find_by(person: alice, edition: edition)
      advance = profile.staff_advances.order(:date).first
      expect(advance.date).to eq(Date.new(2026, 6, 15))
    end

    it "reports correct counts" do
      expect(result[:advances]).to eq(2)
      expect(result[:payments]).to eq(2)
      expect(result[:errors]).to be_empty
    end

    context "idempotency" do
      it "does not create duplicate advances on second run" do
        described_class.new(csv_path: csv_path, edition_id: edition.id).call
        expect {
          described_class.new(csv_path: csv_path, edition_id: edition.id).call
        }.not_to change(StaffAdvance, :count)
      end

      it "does not create duplicate payments on second run" do
        described_class.new(csv_path: csv_path, edition_id: edition.id).call
        expect {
          described_class.new(csv_path: csv_path, edition_id: edition.id).call
        }.not_to change(StaffPayment, :count)
      end
    end

    context "when a row does not match any profile" do
      it "silently skips the row" do
        csv = Tempfile.new([ "vers", ".csv" ])
        csv.write("De,A,Date,Montant,Commentaire\n")
        csv.write("UNKNOWN,,01/07/2026,50,Rien\n")
        csv.close

        expect {
          described_class.new(csv_path: csv.path, edition_id: edition.id).call
        }.not_to change(StaffAdvance, :count)

        csv.unlink
      end
    end
  end
end
