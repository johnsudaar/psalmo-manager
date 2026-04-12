require "rails_helper"

RSpec.describe "Exports", type: :request do
  let(:user)    { create(:user) }
  let(:edition) { create(:edition) }

  before do
    sign_in user
    # Set current_edition by using the session endpoint
    patch update_edition_session_path, params: { edition_id: edition.id }
  end

  # ---------------------------------------------------------------------------
  # Authentication guard
  # ---------------------------------------------------------------------------
  describe "unauthenticated access" do
    before { sign_out user }

    it "redirects to sign-in for the index" do
      get export_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to sign-in for the participants export" do
      get export_participants_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /exports — index page
  # ---------------------------------------------------------------------------
  describe "GET /exports" do
    it "returns 200 OK" do
      get export_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /exports/participants
  # ---------------------------------------------------------------------------
  describe "GET /exports/participants" do
    let(:person) { create(:person, first_name: "Alice", last_name: "Martin") }
    let(:order)  { create(:order, edition: edition) }
    let!(:registration) do
      create(:registration, person: person, order: order, edition: edition,
             age_category: :adulte)
    end

    it "returns a CSV attachment" do
      get export_participants_path
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to match(%r{text/csv})
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end

    it "includes a UTF-8 BOM" do
      get export_participants_path
      expect(response.body.bytes.first(3)).to eq([ 0xEF, 0xBB, 0xBF ])
    end

    it "contains the participant's name" do
      get export_participants_path
      expect(response.body).to include("Alice")
      expect(response.body).to include("Martin")
    end

    it "uses semicolons as separator" do
      get export_participants_path
      expect(response.body).to include(";")
    end

    it "includes the expected header columns" do
      get export_participants_path
      expect(response.body).to include("Prénom")
      expect(response.body).to include("Nom")
      expect(response.body).to include("Catégorie")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /exports/workshop-roster
  # ---------------------------------------------------------------------------
  describe "GET /exports/workshop-roster" do
    let!(:workshop) { create(:workshop, edition: edition, name: "CIRQUE", time_slot: :matin) }
    let(:person)    { create(:person) }
    let(:order)     { create(:order, edition: edition) }
    let!(:registration) { create(:registration, person: person, order: order, edition: edition) }
    let!(:rw) { create(:registration_workshop, registration: registration, workshop: workshop) }

    it "returns a CSV attachment" do
      get export_workshop_roster_csv_path
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to match(%r{text/csv})
    end

    it "includes the workshop name" do
      get export_workshop_roster_csv_path
      expect(response.body).to include("CIRQUE")
    end

    it "includes the participant name" do
      get export_workshop_roster_csv_path
      expect(response.body).to include(person.last_name)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /exports/staff-summary
  # ---------------------------------------------------------------------------
  describe "GET /exports/staff-summary" do
    let(:person)        { create(:person) }
    let!(:staff_profile) { create(:staff_profile, person: person, edition: edition) }

    it "returns a CSV attachment" do
      get export_staff_summary_path
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to match(%r{text/csv})
    end

    it "includes header columns" do
      get export_staff_summary_path
      expect(response.body).to include("N° dossier")
      expect(response.body).to include("Solde (€)")
    end

    it "includes the staff member's name" do
      get export_staff_summary_path
      expect(response.body).to include(person.last_name)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /exports/financial-report
  # ---------------------------------------------------------------------------
  describe "GET /exports/financial-report" do
    it "returns a CSV attachment" do
      get export_financial_report_path
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to match(%r{text/csv})
    end

    it "includes the edition year" do
      get export_financial_report_path
      expect(response.body).to include(edition.year.to_s)
    end

    it "includes standard indicator rows" do
      get export_financial_report_path
      expect(response.body).to include("Total participants")
      expect(response.body).to include("Total billetterie")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /exports/orders-csv
  # ---------------------------------------------------------------------------
  describe "GET /exports/orders-csv" do
    let(:payer) { create(:person, first_name: "Bob", last_name: "Dupont") }
    let!(:order) { create(:order, edition: edition, payer: payer) }

    it "returns a CSV attachment" do
      get export_orders_csv_path
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to match(%r{text/csv})
    end

    it "includes header columns" do
      get export_orders_csv_path
      expect(response.body).to include("Date commande")
      expect(response.body).to include("Payeur")
    end

    it "includes the payer's name" do
      get export_orders_csv_path
      expect(response.body).to include("Dupont")
    end
  end
end
