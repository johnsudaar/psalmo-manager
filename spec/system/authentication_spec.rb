require "rails_helper"

RSpec.describe "Authentication", type: :system do
  let(:user) { create(:user) }

  # ---------------------------------------------------------------------------
  # Login flow
  # ---------------------------------------------------------------------------
  describe "login page" do
    it "shows the login form" do
      visit new_user_session_path
      expect(page).to have_text("Psalmodia — Administration")
      expect(page).to have_field("Adresse e-mail")
      expect(page).to have_field("Mot de passe")
      expect(page).to have_button("Se connecter")
    end

    it "redirects unauthenticated users to sign-in" do
      visit root_path
      expect(page).to have_current_path(new_user_session_path)
    end
  end

  describe "signing in with valid credentials" do
    it "lands on the dashboard" do
      visit new_user_session_path
      fill_in "Adresse e-mail", with: user.email
      fill_in "Mot de passe",   with: "password123"
      click_button "Se connecter"
      expect(page).to have_current_path(root_path)
    end
  end

  describe "signing in with invalid credentials" do
    it "shows an error and stays on sign-in page" do
      visit new_user_session_path
      fill_in "Adresse e-mail", with: user.email
      fill_in "Mot de passe",   with: "wrongpassword"
      click_button "Se connecter"
      expect(page).to have_current_path(new_user_session_path)
    end
  end

  # ---------------------------------------------------------------------------
  # Logout flow
  # ---------------------------------------------------------------------------
  describe "signing out" do
    before do
      sign_in user
      visit root_path
    end

    it "redirects to sign-in page after sign out" do
      click_on "Se déconnecter"
      expect(page).to have_current_path(new_user_session_path)
    end
  end
end
