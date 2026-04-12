require "rails_helper"

RSpec.describe "Participants", type: :system do
  let(:user)     { create(:user) }
  let!(:edition) { create(:edition) }

  before do
    sign_in user
    visit participants_path
  end

  # ---------------------------------------------------------------------------
  # Index page renders
  # ---------------------------------------------------------------------------
  describe "index page" do
    it "shows the participants heading for the current edition" do
      expect(page).to have_text("Participants")
      expect(page).to have_text(edition.name)
    end

    it "shows 'Aucun participant' when none exist" do
      expect(page).to have_text("Aucun participant trouvé")
    end
  end

  # ---------------------------------------------------------------------------
  # Participant list
  # ---------------------------------------------------------------------------
  describe "with participants" do
    let(:person) { create(:person, first_name: "Alice", last_name: "Dupont") }
    let(:order)  { create(:order, edition: edition) }
    let!(:registration) do
      create(:registration, person: person, order: order, edition: edition, age_category: :adulte)
    end

    before { visit participants_path }

    it "lists the participant's full name" do
      expect(page).to have_text("Alice Dupont")
    end

    it "links to the participant show page" do
      click_on "Alice Dupont"
      expect(page).to have_current_path(participant_path(person))
    end

    it "shows the age category" do
      expect(page).to have_text("adulte")
    end

    it "links to the order from the participant page" do
      click_on "Alice Dupont"
      click_on "Ouvrir la commande"

      expect(page).to have_current_path(order_path(order))
    end

    it "links to workshop substitution from the participant page" do
      click_on "Alice Dupont"
      click_on "Modifier les ateliers"

      expect(page).to have_current_path(edit_workshops_participant_path(person, registration_id: registration.id))
    end
  end

  # ---------------------------------------------------------------------------
  # Search filter
  # ---------------------------------------------------------------------------
  describe "search filter" do
    let(:alice_person) { create(:person, first_name: "Alice",   last_name: "Martin") }
    let(:bob_person)   { create(:person, first_name: "Bernard", last_name: "Leroy") }
    let(:order)        { create(:order, edition: edition) }
    let!(:alice_reg)   { create(:registration, person: alice_person, order: order, edition: edition) }
    let!(:bob_reg)     { create(:registration, person: bob_person,   order: create(:order, edition: edition), edition: edition) }

    before { visit participants_path }

    it "filters participants by name" do
      fill_in "Recherche", with: "Alice"
      click_button "Filtrer"
      expect(page).to     have_text("Alice Martin")
      expect(page).not_to have_text("Bernard Leroy")
    end
  end

  # ---------------------------------------------------------------------------
  # Unaccompanied minor badge
  # ---------------------------------------------------------------------------
  describe "unaccompanied minor flag" do
    let(:child)  { create(:person, first_name: "Léo", last_name: "Petit") }
    let(:order)  { create(:order, edition: edition) }
    let!(:reg)   { create(:registration, person: child, order: order, edition: edition, is_unaccompanied_minor: true) }

    before { visit participants_path }

    it "shows the Mineur badge" do
      expect(page).to have_text("Mineur")
    end
  end
end
