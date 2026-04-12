require "rails_helper"

RSpec.describe "StaffProfiles", type: :request do
  let(:user)    { create(:user) }
  let(:edition) { create(:edition) }

  before do
    sign_in user
    patch update_edition_session_path, params: { edition_id: edition.id }
  end

  describe "unauthenticated access" do
    before { sign_out user }

    it "redirects to sign-in for index" do
      get staff_profiles_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to sign-in for show" do
      staff_profile = create(:staff_profile, edition: edition)
      get staff_profile_path(staff_profile)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /staff_profiles" do
    it "renders successfully with a linked person profile" do
      create(:staff_profile, edition: edition)
      get staff_profiles_path
      expect(response).to have_http_status(:ok)
    end

    it "renders successfully with a direct-entry profile" do
      create(:staff_profile, person: nil, edition: edition, first_name: "Marie", last_name: "Dupont")
      get staff_profiles_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Marie Dupont")
    end
  end

  describe "GET /staff_profiles/new" do
    it "renders successfully" do
      get new_staff_profile_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /staff_profiles" do
    it "creates a profile from direct-entry fields" do
      expect {
        post staff_profiles_path, params: {
          staff_profile: {
            first_name: "Marie",
            last_name: "Dupont",
            email: "marie@example.test"
          }
        }
      }.to change(StaffProfile, :count).by(1)

      expect(response).to redirect_to(staff_profile_path(StaffProfile.last))
      expect(StaffProfile.last.person).to be_nil
    end

    it "re-renders the form with submitted values on validation failure" do
      post staff_profiles_path, params: {
        staff_profile: {
          first_name: "Marie",
          last_name: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Marie")
    end
  end

  describe "GET /staff_profiles/:id" do
    it "renders successfully for a direct-entry profile" do
      staff_profile = create(:staff_profile, person: nil, edition: edition, first_name: "Marie", last_name: "Dupont")
      get staff_profile_path(staff_profile)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Marie Dupont")
    end
  end

  describe "GET /staff_profiles/:id/edit" do
    it "renders successfully for a direct-entry profile" do
      staff_profile = create(:staff_profile, person: nil, edition: edition, first_name: "Marie", last_name: "Dupont")
      get edit_staff_profile_path(staff_profile)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Marie Dupont")
    end
  end
end
