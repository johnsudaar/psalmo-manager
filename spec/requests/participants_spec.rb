require "rails_helper"

RSpec.describe "Participants", type: :request do
  let(:user)    { create(:user) }
  let(:edition) { create(:edition) }

  let(:alice) { create(:person, first_name: "Alice", last_name: "Martin") }
  let(:bob)   { create(:person, first_name: "Bernard", last_name: "Leroy") }

  let!(:alice_registration) do
    create(:registration,
           person: alice,
           order: create(:order, edition: edition),
           edition: edition,
           age_category: :enfant,
           is_unaccompanied_minor: true)
  end

  let!(:bob_registration) do
    create(:registration,
           person: bob,
           order: create(:order, edition: edition),
           edition: edition,
           age_category: :adulte,
           has_conflict: true,
           excluded_from_stats: true)
  end

  before do
    sign_in user
    allow_any_instance_of(ApplicationController).to receive(:current_edition).and_return(edition)
  end

  describe "GET /participants" do
    it "renders the table inside the participant filter turbo frame" do
      get participants_path

      expect(response.body).to match(/turbo-frame id="participant_filter".*<table class="min-w-full divide-y divide-gray-200">/m)
    end

    it "opens participant links outside the turbo frame" do
      get participants_path

      expect(response.body).to include("data-turbo-frame=\"_top\"")
    end

    it "filters by name" do
      get participants_path, params: { q: "alice" }

      expect(response.body).to include("Alice Martin")
      expect(response.body).not_to include("Bernard Leroy")
    end

    it "filters by age category" do
      get participants_path, params: { age_category: "enfant" }

      expect(response.body).to include("Alice Martin")
      expect(response.body).not_to include("Bernard Leroy")
    end

    it "filters by workshop" do
      cirque = create(:workshop, edition: edition, name: "CIRQUE", time_slot: :matin)
      danse = create(:workshop, edition: edition, name: "DANSE", time_slot: :apres_midi)
      create(:registration_workshop, registration: alice_registration, workshop: cirque)
      create(:registration_workshop, registration: bob_registration, workshop: danse)

      get participants_path, params: { workshop_id: cirque.id }

      expect(response.body).to include("Alice Martin")
      expect(response.body).not_to include("Bernard Leroy")
    end

    it "filters by unaccompanied minors" do
      get participants_path, params: { unaccompanied_minors: "1" }

      expect(response.body).to include("Alice Martin")
      expect(response.body).not_to include("Bernard Leroy")
    end

    it "filters by conflicts" do
      get participants_path, params: { with_conflicts: "1" }

      expect(response.body).to include("Bernard Leroy")
      expect(response.body).not_to include("Alice Martin")
    end

    it "filters by excluded from stats" do
      get participants_path, params: { excluded_from_stats: "1" }

      expect(response.body).to include("Bernard Leroy")
      expect(response.body).not_to include("Alice Martin")
    end
  end
end
