require "rails_helper"

RSpec.describe "Workshop substitution", type: :system do
  let(:user)    { create(:user) }
  let(:edition) { create(:edition) }

  # Two workshops in the same time slot so we can substitute between them
  let!(:workshop_a) { create(:workshop, edition: edition, name: "CIRQUE",    time_slot: :matin, capacity: 20) }
  let!(:workshop_b) { create(:workshop, edition: edition, name: "MARMITONS", time_slot: :matin, capacity: 20) }

  let(:person)  { create(:person, first_name: "Paul", last_name: "Moreau") }
  let(:order)   { create(:order, edition: edition) }
  let!(:registration) { create(:registration, person: person, order: order, edition: edition) }
  let!(:rw) { create(:registration_workshop, registration: registration, workshop: workshop_a) }

  before do
    sign_in user
  end

  # ---------------------------------------------------------------------------
  # Index / search page
  # ---------------------------------------------------------------------------
  describe "index page" do
    it "shows the search form" do
      visit workshop_substitutions_path
      expect(page).to have_text("Changements d'atelier")
      expect(page).to have_field("Rechercher un participant")
    end

    it "finds the participant by name" do
      visit workshop_substitutions_path
      fill_in "Rechercher un participant", with: "Paul"
      click_button "Rechercher"
      expect(page).to have_text("Paul Moreau")
    end

    it "links to the substitution form" do
      visit workshop_substitutions_path
      fill_in "Rechercher un participant", with: "Paul"
      click_button "Rechercher"
      click_on "Sélectionner"
      expect(page).to have_current_path(new_workshop_substitution_path(registration_id: registration.id))
    end
  end

  # ---------------------------------------------------------------------------
  # New substitution form
  # ---------------------------------------------------------------------------
  describe "substitution form" do
    before { visit new_workshop_substitution_path(registration_id: registration.id) }

    it "shows the participant's current workshops" do
      expect(page).to have_text("CIRQUE")
    end

    it "shows the available workshops in the dropdown" do
      expect(page).to have_text("MARMITONS")
    end
  end

  # ---------------------------------------------------------------------------
  # Applying a substitution
  # ---------------------------------------------------------------------------
  describe "applying a substitution" do
    before { visit new_workshop_substitution_path(registration_id: registration.id) }

    it "replaces the workshop and redirects with a flash message" do
      # Select MARMITONS in the workshop substitution select
      find("select[name='new_workshop_id']").find("option", text: "MARMITONS").select_option
      click_button "Appliquer"

      # Should redirect to substitutions index with success message
      expect(page).to have_text("Changement appliqué")

      # The registration should now have MARMITONS (is_override: true)
      override_rw = registration.registration_workshops.reload.find_by(is_override: true)
      expect(override_rw).not_to be_nil
      expect(override_rw.workshop.name).to eq("MARMITONS")
    end
  end
end
