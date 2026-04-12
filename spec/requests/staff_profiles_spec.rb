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

    it "renders edition-configured select options" do
      edition.update!(transport_modes: "Train\nVoiture", allowance_labels: "Cachet\nPrestation")
      staff_profile = create(:staff_profile, edition: edition, transport_mode: "Train", allowance_label: "Cachet")

      get staff_profile_path(staff_profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<option selected=\"selected\" value=\"Train\">Train</option>")
      expect(response.body).to include("<option selected=\"selected\" value=\"Cachet\">Cachet</option>")
      expect(response.body).to include("target=\"_blank\"")
    end

    it "defaults the allowance label to the first configured option" do
      edition.update!(allowance_labels: "Cachet\nPrestation")
      staff_profile = create(:staff_profile, edition: edition, allowance_label: nil)

      get staff_profile_path(staff_profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<option selected=\"selected\" value=\"Cachet\">Cachet</option>")
      allowance_select = response.body[/<select name=\"staff_profile\[allowance_label\]\".*?<\/select>/m]
      expect(allowance_select).to be_present
      expect(allowance_select).not_to include("<option value=\"\"")
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

  describe "PATCH /staff_profiles/:id" do
    it "updates a field through the turbo-stream autosave path" do
      staff_profile = create(:staff_profile, edition: edition, allowance_cents: 20_000)

      patch staff_profile_path(staff_profile),
            params: { staff_profile: { allowance_cents: "234,56" } },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(staff_profile.reload.allowance_cents).to eq(23_456)
    end

    it "clears the km rate override when submitted blank" do
      staff_profile = create(:staff_profile, edition: edition, km_rate_override_cents: 41)

      patch staff_profile_path(staff_profile),
            params: { staff_profile: { km_rate_override_cents: "" } },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(staff_profile.reload.km_rate_override_cents).to be_nil
    end

    it "accepts decimal euros for the km rate override" do
      staff_profile = create(:staff_profile, edition: edition, km_rate_override_cents: nil)

      patch staff_profile_path(staff_profile),
            params: { staff_profile: { km_rate_override_cents: "0,41" } },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(staff_profile.reload.km_rate_override_cents).to eq(41)
    end

    it "accepts a raw travel expense override" do
      staff_profile = create(:staff_profile, edition: edition, travel_override_cents: nil)

      patch staff_profile_path(staff_profile),
            params: { staff_profile: { travel_override_cents: "45,50" } },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(staff_profile.reload.travel_override_cents).to eq(4550)
    end

    it "resets traveled kilometers to zero when submitted blank" do
      staff_profile = create(:staff_profile, edition: edition, km_traveled: 150)

      patch staff_profile_path(staff_profile),
            params: { staff_profile: { km_traveled: "" } },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(staff_profile.reload.km_traveled).to eq(0)
    end

    it "clears the travel expense override when submitted blank" do
      staff_profile = create(:staff_profile, edition: edition, travel_override_cents: 4550)

      patch staff_profile_path(staff_profile),
            params: { staff_profile: { travel_override_cents: "" } },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(staff_profile.reload.travel_override_cents).to be_nil
    end
  end

  describe "DELETE /staff_profiles/:id" do
    it "deletes the staff profile and redirects to the index" do
      staff_profile = create(:staff_profile, edition: edition)

      expect {
        delete staff_profile_path(staff_profile)
      }.to change(StaffProfile, :count).by(-1)

      expect(response).to redirect_to(staff_profiles_path)
      follow_redirect!
      expect(response.body).to include("Dossier supprimé.")
    end

    it "deletes dependent advances and payments" do
      staff_profile = create(:staff_profile, edition: edition)
      create(:staff_advance, staff_profile: staff_profile)
      create(:staff_payment, staff_profile: staff_profile)

      expect {
        delete staff_profile_path(staff_profile)
      }.to change(StaffAdvance, :count).by(-1)
       .and change(StaffPayment, :count).by(-1)
    end
  end
end
