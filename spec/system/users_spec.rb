require "rails_helper"

RSpec.describe "Users", type: :system do
  let(:user) { create(:user, email: "admin@example.test") }

  before do
    sign_in user
  end

  it "shows the users section in the sidebar" do
    visit root_path

    expect(page).to have_text("Administration")
    expect(page).to have_link("Utilisateurs", href: users_path)
  end

  it "creates a new user" do
    visit users_path
    click_on "Nouvel utilisateur"

    fill_in "Email", with: "new.user@example.test"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    click_button "Créer l'utilisateur"

    expect(page).to have_current_path(users_path)
    expect(page).to have_text("Utilisateur créé")
    expect(page).to have_text("new.user@example.test")
  end

  it "deletes another user" do
    other_user = create(:user, email: "other.user@example.test")

    visit users_path
    within("tr", text: other_user.email) do
      click_button "Supprimer"
    end

    expect(page).to have_current_path(users_path)
    expect(page).to have_text("Utilisateur supprimé")
    expect(page).not_to have_text("other.user@example.test")
  end

  it "does not allow deleting the current user" do
    visit users_path

    expect(page).to have_text("Compte courant")
    expect(page).not_to have_button("Supprimer", count: 1)
  end
end
