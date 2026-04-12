require "rails_helper"

RSpec.describe Helloasso::SyncService do
  let(:edition) do
    create(:edition, year: 2026, helloasso_form_slug: "psalmodia-2026",
                     start_date: Date.new(2026, 7, 1))
  end

  let(:fixture_path) { Rails.root.join("spec/fixtures/helloasso/orders_page1.json") }
  let(:orders_body)  { File.read(fixture_path) }

  let(:token_response) do
    { access_token: "fake-token", token_type: "Bearer", expires_in: 1800 }.to_json
  end

  around do |example|
    # NullStore is used in test env; swap in a real MemoryStore so token caching works
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = original_cache
  end

  before do
    stub_request(:post, "https://api.helloasso.com/oauth2/token")
      .to_return(
        status: 200,
        body: token_response,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, %r{api\.helloasso\.com/v5/organizations/.*/forms/Event/psalmodia-2026/orders})
      .to_return(
        status: 200,
        body: orders_body,
        headers: { "Content-Type" => "application/json" }
      )

    # Create the workshops referenced in the fixture
    create(:workshop, edition: edition, name: "CIRQUE", time_slot: :matin)
    create(:workshop, edition: edition, name: "DANSE",  time_slot: :matin)
  end

  subject(:sync) { described_class.new(edition) }

  describe "#call" do
    it "creates an Order record" do
      expect { sync.call }.to change(Order, :count).by(1)
    end

    it "creates Person records for payer and distinct participant" do
      # fixture has 2 items: Léa (child) and Marie (adult = same as payer)
      expect { sync.call }.to change(Person, :count).by(2)
    end

    it "creates Registration records for each item" do
      expect { sync.call }.to change(Registration, :count).by(2)
    end

    it "creates RegistrationWorkshop records for non-blank customFields" do
      # Léa → CIRQUE, Marie → DANSE (blank answers are skipped)
      expect { sync.call }.to change(RegistrationWorkshop, :count).by(2)
    end

    it "stores helloasso_raw on the order" do
      sync.call
      expect(Order.last.helloasso_raw).to be_a(Hash)
    end

    it "infers age_category from dateOfBirth" do
      sync.call
      lea   = Registration.joins(:person).where(people: { email: "lea.dupont@example.com" }).first
      marie = Registration.joins(:person).where(people: { email: "marie.dupont@example.com" }).first
      expect(lea.age_category).to   eq("enfant")
      expect(marie.age_category).to eq("adulte")
    end

    it "converts amounts to cents" do
      sync.call
      lea_reg = Registration.joins(:person).where(people: { email: "lea.dupont@example.com" }).first
      expect(lea_reg.ticket_price_cents).to eq(10_000)
      expect(lea_reg.discount_cents).to     eq(1_000)
    end

    context "when run twice (idempotency)" do
      it "does not create duplicate Orders" do
        sync.call
        expect { sync.call }.not_to change(Order, :count)
      end

      it "does not create duplicate Registrations" do
        sync.call
        expect { sync.call }.not_to change(Registration, :count)
      end
    end

    context "override-preservation contract" do
      it "does not overwrite workshop assignments when a manual override is active" do
        sync.call

        lea_reg = Registration.joins(:person).where(people: { email: "lea.dupont@example.com" }).first
        # Simulate an admin-applied workshop substitution
        override_workshop = create(:workshop, edition: edition, name: "JONGLAGE", time_slot: :apres_midi)
        lea_reg.registration_workshops.destroy_all
        override_rw = lea_reg.registration_workshops.create!(
          workshop: override_workshop,
          price_paid_cents: 0,
          is_override: true
        )
        lea_reg.update!(
          has_workshop_override: true,
          workshop_override_backup: [
            { workshop_id: Workshop.find_by!(edition: edition, name: "CIRQUE").id, price_paid_cents: 0 }
          ]
        )

        sync.call

        lea_reg.reload
        expect(RegistrationWorkshop.find_by(id: override_rw.id)).to be_present
        expect(lea_reg.registration_workshops.pluck(:workshop_id)).to eq([override_workshop.id])
        expect(lea_reg.has_workshop_override).to be(true)
      end

      it "does not overwrite excluded_from_stats" do
        sync.call
        reg = Registration.first
        reg.update!(excluded_from_stats: true)

        sync.call

        expect(reg.reload.excluded_from_stats).to be true
      end

      it "does not overwrite is_unaccompanied_minor" do
        sync.call
        reg = Registration.first
        reg.update!(is_unaccompanied_minor: true)

        sync.call

        expect(reg.reload.is_unaccompanied_minor).to be true
      end
    end

    context "when a workshop from customFields is not found in the DB" do
      before do
        Workshop.where(edition: edition, name: "DANSE").destroy_all
      end

      it "skips the missing workshop without raising" do
        expect { sync.call }.not_to raise_error
      end

      it "still creates RegistrationWorkshop for the workshops that do exist" do
        sync.call
        # Only CIRQUE exists; DANSE was deleted → 1 rw instead of 2
        expect(RegistrationWorkshop.count).to eq(1)
      end
    end
  end
end
