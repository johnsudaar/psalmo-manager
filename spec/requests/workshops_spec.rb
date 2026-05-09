require "rails_helper"

RSpec.describe "Workshops", type: :request do
  let(:user)     { create(:user) }
  let(:edition)  { create(:edition) }
  let(:workshop) { create(:workshop, edition: edition, name: "CIRQUE") }

  before do
    sign_in user
    patch update_edition_session_path, params: { edition_id: edition.id }
  end

  describe "GET /workshops/:id" do
    it "shows the participant date of birth" do
      person = create(:person, date_of_birth: Date.new(2012, 5, 4))
      order = create(:order, edition: edition, payer: create(:person, email: "payer@example.test"))
      registration = create(:registration, person: person, order: order, edition: edition)
      create(:registration_workshop, registration: registration, workshop: workshop)

      get workshop_path(workshop)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("04/05/2012")
    end

    it "falls back to the payer email when the participant email is blank" do
      payer = create(:person, email: "payer@example.test")
      person = create(:person, email: nil)
      order = create(:order, edition: edition, payer: payer)
      registration = create(:registration, person: person, order: order, edition: edition)
      create(:registration_workshop, registration: registration, workshop: workshop)

      get workshop_path(workshop)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("payer@example.test")
    end
  end
end
