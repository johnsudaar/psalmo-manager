require "rails_helper"

RSpec.describe Actors::RemoveWorkshopOverride do
  let(:edition) { create(:edition) }
  let(:workshop_a) { create(:workshop, edition: edition, time_slot: :matin) }
  let(:workshop_b) { create(:workshop, edition: edition, time_slot: :apres_midi) }
  let(:registration) { create(:registration, edition: edition, has_workshop_override: true) }

  before do
    create(:registration_workshop,
      registration: registration,
      workshop: workshop_b,
      price_paid_cents: 0,
      is_override: true)

    registration.update!(
      workshop_override_backup: [
        { workshop_id: workshop_a.id, price_paid_cents: 4500 }
      ]
    )
  end

  it "restores the backed up workshops" do
    described_class.call(registration: registration)

    restored = registration.registration_workshops.reload.find_by(workshop: workshop_a)
    expect(restored).to be_present
    expect(restored.price_paid_cents).to eq(4500)
    expect(restored.is_override).to be(false)
  end

  it "removes the override flag and backup" do
    described_class.call(registration: registration)

    expect(registration.reload.has_workshop_override).to be(false)
    expect(registration.workshop_override_backup).to eq([])
  end
end
