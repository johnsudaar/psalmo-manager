require "rails_helper"

RSpec.describe Actors::AddStaffAdvance do
  let(:staff_profile) { create(:staff_profile) }

  context "happy path" do
    subject(:result) do
      described_class.call(
        staff_profile: staff_profile,
        date:          "2026-06-15",
        amount_cents:  5000,
        comment:       "Acompte initial"
      )
    end

    it "succeeds" do
      expect(result).to be_success
    end

    it "creates a StaffAdvance" do
      expect { result }.to change(StaffAdvance, :count).by(1)
    end

    it "sets context.staff_advance" do
      expect(result.staff_advance).to be_a(StaffAdvance)
    end

    it "associates the advance with the profile" do
      result
      expect(staff_profile.staff_advances.first.amount_cents).to eq(5000)
    end
  end

  context "when validation fails (missing date)" do
    subject(:result) do
      described_class.call(staff_profile: staff_profile, date: nil, amount_cents: 5000)
    end

    it "fails" do
      expect(result).to be_failure
    end

    it "sets context.error" do
      expect(result.error).to be_present
    end
  end
end

RSpec.describe Actors::RemoveStaffAdvance do
  let!(:advance) { create(:staff_advance) }

  it "destroys the advance" do
    expect { described_class.call(staff_advance: advance) }.to change(StaffAdvance, :count).by(-1)
  end

  it "succeeds" do
    expect(described_class.call(staff_advance: advance)).to be_success
  end
end

RSpec.describe Actors::AddStaffPayment do
  let(:staff_profile) { create(:staff_profile) }

  subject(:result) do
    described_class.call(
      staff_profile: staff_profile,
      date:          "2026-07-01",
      amount_cents:  20000,
      comment:       "Virement"
    )
  end

  it "succeeds" do
    expect(result).to be_success
  end

  it "creates a StaffPayment" do
    expect { result }.to change(StaffPayment, :count).by(1)
  end

  it "sets context.staff_payment" do
    expect(result.staff_payment).to be_a(StaffPayment)
  end
end

RSpec.describe Actors::RemoveStaffPayment do
  let!(:payment) { create(:staff_payment) }

  it "destroys the payment" do
    expect { described_class.call(staff_payment: payment) }.to change(StaffPayment, :count).by(-1)
  end

  it "succeeds" do
    expect(described_class.call(staff_payment: payment)).to be_success
  end
end
