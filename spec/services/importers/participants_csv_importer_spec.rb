require "rails_helper"

RSpec.describe Importers::ParticipantsCsvImporter do
  let(:csv_path) { Rails.root.join("spec/fixtures/csv/donnes_brutes_sample.csv").to_s }
  let(:edition)  { create(:edition, year: 2026, start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 15)) }

  subject(:result) { described_class.new(csv_path: csv_path, edition_id: edition.id).call }

  describe "#call" do
    it "returns a result hash" do
      expect(result).to include(:created, :updated, :errors)
    end

    it "creates the expected number of registrations" do
      expect { result }.to change(Registration, :count).by(4)
    end

    it "creates person records for participants" do
      result
      expect(Person.find_by(first_name: "Alice", last_name: "Testenfant")).to be_present
      expect(Person.find_by(first_name: "Carol", last_name: "Testadulte")).to be_present
      expect(Person.find_by(first_name: "Dave",  last_name: "Testmineur")).to be_present
    end

    it "creates a separate payer person when payer differs from participant" do
      result
      # BIL-003: participant = Dave Testmineur, payer = Eve Testautre
      expect(Person.find_by(email: "eve.testautre@example.test")).to be_present
    end

    it "reuses the same person record when payer == participant" do
      result
      # BIL-004: participant Frank Testsansdob is also the payer
      frank = Person.find_by(email: "frank.testsansdob@example.test")
      order = Order.find_by(helloasso_order_id: "CMD-003")
      expect(order.payer_id).to eq(frank.id)
    end

    it "creates one Order per Référence commande" do
      expect { result }.to change(Order, :count).by(3) # CMD-001, CMD-002, CMD-003
    end

    it "creates RegistrationWorkshop records for non-zero workshop columns" do
      result
      reg = Registration.find_by(helloasso_ticket_id: "BIL-001")
      workshop_names = reg.workshops.pluck(:name)
      expect(workshop_names).to include("CIRQUE", "MARMITONS")
      expect(workshop_names).not_to include("THÉATRE ENFANTS")
    end

    it "infers enfant age_category from date_of_birth" do
      result
      # Alice born 15/08/2015 → 10 years old at start of 2026 edition → enfant
      reg = Registration.find_by(helloasso_ticket_id: "BIL-001")
      expect(reg.age_category).to eq("enfant")
    end

    it "infers adulte age_category from date_of_birth" do
      result
      # Carol born 20/03/1985 → 41 years old → adulte
      reg = Registration.find_by(helloasso_ticket_id: "BIL-002")
      expect(reg.age_category).to eq("adulte")
    end

    it "defaults to enfant when date_of_birth is missing" do
      result
      # BIL-004 has no date of birth
      reg = Registration.find_by(helloasso_ticket_id: "BIL-004")
      expect(reg.age_category).to eq("enfant")
    end

    it "converts euro amounts to cents" do
      result
      reg = Registration.find_by(helloasso_ticket_id: "BIL-002")
      expect(reg.ticket_price_cents).to eq(12000)
      expect(reg.discount_cents).to eq(1000)
    end

    it "stores promo_code and promo_amount on order" do
      result
      order = Order.find_by(helloasso_order_id: "CMD-002")
      expect(order.promo_code).to eq("PROMO10")
      expect(order.promo_amount_cents).to eq(500)
    end

    it "stores date_of_birth on the person" do
      result
      alice = Person.find_by(first_name: "Alice", last_name: "Testenfant")
      expect(alice.date_of_birth).to eq(Date.new(2015, 8, 15))
    end

    context "idempotency" do
      it "does not create duplicate registrations on second run" do
        described_class.new(csv_path: csv_path, edition_id: edition.id).call
        expect {
          described_class.new(csv_path: csv_path, edition_id: edition.id).call
        }.not_to change(Registration, :count)
      end

      it "does not create duplicate orders on second run" do
        described_class.new(csv_path: csv_path, edition_id: edition.id).call
        expect {
          described_class.new(csv_path: csv_path, edition_id: edition.id).call
        }.not_to change(Order, :count)
      end

      it "does not overwrite is_override: true RegistrationWorkshops" do
        described_class.new(csv_path: csv_path, edition_id: edition.id).call

        reg      = Registration.find_by(helloasso_ticket_id: "BIL-001")
        workshop = Workshop.find_by(edition: edition, name: "CIRQUE")
        # Manually set an override
        rw = reg.registration_workshops.find_by!(workshop: workshop)
        rw.update!(is_override: true, price_paid_cents: 9999)

        # Run again
        described_class.new(csv_path: csv_path, edition_id: edition.id).call

        expect(rw.reload.price_paid_cents).to eq(9999)
        expect(rw.reload.is_override).to be(true)
      end
    end

    context "when a row raises an error" do
      it "collects the error and continues" do
        csv = Tempfile.new([ "bad", ".csv" ])
        csv.write("Référence commande,Date de la commande,Statut de la commande,Nom participant,Prénom participant,Nom payeur,Prénom payeur,Email payeur,Raison sociale,Moyen de paiement,Billet,Numéro de billet,Tarif,Montant tarif,Code Promo,Montant code promo,CIRQUE,Montant CIRQUE\n")
        csv.write(",10/06/2026 10:00,Validé,,,Test,Payeur,payeur@example.test,,,,, Enfant,\"80,00\",,,Oui,\"50,00\"\n") # blank ticket id → validation error
        csv.write("CMD-OK,10/06/2026 10:00,Validé,Test,Valid,Test,Valid,valid@example.test,,,, BIL-VALID,Enfant,\"80,00\",,,Oui,\"50,00\"\n")
        csv.close

        result = described_class.new(csv_path: csv.path, edition_id: edition.id).call
        csv.unlink

        expect(result[:errors]).not_to be_empty
        expect(Registration.find_by(helloasso_ticket_id: "BIL-VALID")).to be_present
      end
    end
  end
end

RSpec.describe Importers::FiltresCsvImporter do
  let(:edition) { create(:edition, year: 2026, start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 15)) }

  before do
    # Set up prerequisite data
    Importers::ParticipantsCsvImporter.new(
      csv_path:   Rails.root.join("spec/fixtures/csv/donnes_brutes_sample.csv").to_s,
      edition_id: edition.id
    ).call
  end

  let(:csv_path) { Rails.root.join("spec/fixtures/csv/filtres_sample.csv").to_s }

  subject(:result) { described_class.new(csv_path: csv_path, edition_id: edition.id).call }

  describe "#call" do
    it "creates an is_override: true RegistrationWorkshop" do
      result
      reg      = Registration.find_by(helloasso_ticket_id: "BIL-001")
      # filtres_sample removes CIRQUE (value 0), adds THÉATRE ENFANTS (40)
      theatre = Workshop.find_by(edition: edition, name: "THÉATRE ENFANTS")
      rw = reg.registration_workshops.find_by!(workshop: theatre)
      expect(rw.is_override).to be(true)
      expect(rw.price_paid_cents).to eq(4000)
    end

    it "reports the number applied" do
      expect(result[:applied]).to eq(1)
      expect(result[:errors]).to be_empty
    end
  end
end

RSpec.describe Importers::ExclusionsCsvImporter do
  let(:edition) { create(:edition, year: 2026, start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 15)) }

  before do
    Importers::ParticipantsCsvImporter.new(
      csv_path:   Rails.root.join("spec/fixtures/csv/donnes_brutes_sample.csv").to_s,
      edition_id: edition.id
    ).call
  end

  let(:csv_path) { Rails.root.join("spec/fixtures/csv/exclusions_sample.csv").to_s }

  subject(:result) { described_class.new(csv_path: csv_path, edition_id: edition.id).call }

  describe "#call" do
    it "sets excluded_from_stats on the matching registration" do
      result
      reg = Registration.find_by(helloasso_ticket_id: "BIL-002")
      expect(reg.excluded_from_stats).to be(true)
    end

    it "does not affect other registrations" do
      result
      reg = Registration.find_by(helloasso_ticket_id: "BIL-001")
      expect(reg.excluded_from_stats).to be(false)
    end

    it "reports the number applied" do
      expect(result[:applied]).to eq(1)
      expect(result[:errors]).to be_empty
    end
  end
end

RSpec.describe Importers::MineursCsvImporter do
  let(:edition) { create(:edition, year: 2026, start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 15)) }

  before do
    Importers::ParticipantsCsvImporter.new(
      csv_path:   Rails.root.join("spec/fixtures/csv/donnes_brutes_sample.csv").to_s,
      edition_id: edition.id
    ).call
  end

  let(:csv_path) { Rails.root.join("spec/fixtures/csv/mineurs_sample.csv").to_s }

  subject(:result) { described_class.new(csv_path: csv_path, edition_id: edition.id).call }

  describe "#call" do
    it "sets is_unaccompanied_minor on the matching registration" do
      result
      reg = Registration.find_by(helloasso_ticket_id: "BIL-003")
      expect(reg.is_unaccompanied_minor).to be(true)
    end

    it "sets responsible_person_note" do
      result
      reg = Registration.find_by(helloasso_ticket_id: "BIL-003")
      expect(reg.responsible_person_note).to eq("Responsabilité Claire Martin")
    end

    it "does not affect other registrations" do
      result
      reg = Registration.find_by(helloasso_ticket_id: "BIL-001")
      expect(reg.is_unaccompanied_minor).to be(false)
    end

    it "reports the number applied" do
      expect(result[:applied]).to eq(1)
      expect(result[:errors]).to be_empty
    end
  end
end
