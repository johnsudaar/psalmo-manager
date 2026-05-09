require "rails_helper"

RSpec.describe "Participant workshop management", type: :system do
  let(:user)    { create(:user) }
  let(:edition) { create(:edition) }

  let!(:workshop_a) { create(:workshop, edition: edition, name: "CIRQUE", time_slot: :matin, capacity: 20) }
  let!(:workshop_b) { create(:workshop, edition: edition, name: "MARMITONS", time_slot: :apres_midi, capacity: 20) }
  let!(:workshop_c) { create(:workshop, edition: edition, name: "CHORALE", time_slot: :matin, capacity: 20) }

  let(:person)  { create(:person, first_name: "Paul", last_name: "Moreau") }
  let(:order)   { create(:order, edition: edition) }
  let!(:registration) { create(:registration, person: person, order: order, edition: edition) }
  let!(:rw) { create(:registration_workshop, registration: registration, workshop: workshop_a) }

  before do
    sign_in user
  end

  describe "editing workshops from the participant page" do
    it "opens the workshop edit page from the participant page" do
      visit participant_path(person)
      click_on "Modifier les ateliers"

      expect(page).to have_current_path(edit_workshops_participant_path(person, registration_id: registration.id))
    end

    it "returns to the participant page after updating workshops" do
      visit edit_workshops_participant_path(person, registration_id: registration.id)
      check "MARMITONS"
      click_button "Enregistrer"

      expect(page).to have_current_path(participant_path(person))
      expect(page).to have_text("Ateliers mis à jour")
      expect(page).to have_text("MARMITONS")
    end

    it "shows when a registration has an override and allows deleting it" do
      registration.update!(
        has_workshop_override: true,
        workshop_override_backup: [
          { workshop_id: workshop_a.id, price_paid_cents: 0 }
        ]
      )
      registration.registration_workshops.update_all(is_override: true)

      visit participant_path(person)

      expect(page).to have_text("(changé)")
      expect(page).to have_text("Cette inscription a un changement d'atelier manuel")
      expect(page).to have_text("Ateliers d'origine : CIRQUE")

      click_button "Supprimer le changement"

      expect(page).to have_current_path(participant_path(person))
      expect(page).to have_text("Changement d'atelier supprimé")
      expect(registration.registration_workshops.reload.map(&:workshop_id)).to eq([workshop_a.id])
      expect(registration.reload.has_workshop_override).to be(false)
    end

    it "restores the original workshops after removing them all" do
      visit edit_workshops_participant_path(person, registration_id: registration.id)
      uncheck "CIRQUE"
      click_button "Enregistrer"

      expect(page).to have_text("Aucun atelier.")
      expect(page).to have_text("Cette inscription a un changement d'atelier manuel")
      expect(page).to have_text("Ateliers d'origine : CIRQUE")

      click_button "Supprimer le changement"

      expect(page).to have_current_path(participant_path(person))
      expect(page).to have_text("CIRQUE")
      expect(registration.registration_workshops.reload.map(&:workshop_id)).to eq([workshop_a.id])
    end

    it "shows the override even when all workshops were removed" do
      registration.registration_workshops.destroy_all
      registration.update!(
        has_workshop_override: true,
        workshop_override_backup: [
          { workshop_id: workshop_a.id, price_paid_cents: 0 }
        ]
      )

      visit participant_path(person)

      expect(page).to have_text("Aucun atelier.")
      expect(page).to have_text("Cette inscription a un changement d'atelier manuel")
      expect(page).to have_text("Ateliers d'origine : CIRQUE")
    end
  end
end
