require "rails_helper"

RSpec.describe "Staff profile", type: :system do
  let(:user)    { create(:user) }
  let(:edition) { create(:edition) }
  let(:person)  { create(:person, first_name: "Marie", last_name: "Dupont") }
  let!(:staff_profile) do
    create(:staff_profile,
           person: person,
           edition: edition,
           allowance_cents: 20_000,
           km_traveled: 150)
  end

  before do
    sign_in user
    visit staff_profile_path(staff_profile)
  end

  # ---------------------------------------------------------------------------
  # Show page renders correctly
  # ---------------------------------------------------------------------------
  describe "show page" do
    it "shows the dossier number and staff name" do
      expect(page).to have_text("Dossier ##{staff_profile.dossier_number}")
      expect(page).to have_text("Marie Dupont")
    end

    it "shows the financial summary section" do
      expect(page).to have_text("Résumé financier")
    end

    it "shows the advances section" do
      expect(page).to have_text("Acomptes")
    end

    it "shows the payments section" do
      expect(page).to have_text("Versements")
    end

    it "has a link to generate the PDF" do
      expect(page).to have_link("Générer la fiche PDF")
    end
  end

  # ---------------------------------------------------------------------------
  # Adding a staff advance via the form
  # ---------------------------------------------------------------------------
  describe "adding a staff advance" do
    it "adds the advance and shows it in the advances section" do
      within "turbo-frame#staff_advances" do
        fill_in "Date",               with: "2026-03-15"
        fill_in "Montant (centimes)", with: "5000"
        fill_in "Commentaire",        with: "Acompte test"
        click_button "Ajouter"
      end

      expect(page).to have_text("50,00 €")
      expect(page).to have_text("Acompte test")
    end
  end

  # ---------------------------------------------------------------------------
  # Removing a staff advance
  # ---------------------------------------------------------------------------
  describe "removing a staff advance" do
    let!(:advance) do
      create(:staff_advance, staff_profile: staff_profile, amount_cents: 3000, comment: "À supprimer")
    end

    before { visit staff_profile_path(staff_profile) }

    it "removes the advance row" do
      expect(page).to have_text("À supprimer")
      click_on "Supprimer"
      expect(page).not_to have_text("À supprimer")
    end
  end
end
