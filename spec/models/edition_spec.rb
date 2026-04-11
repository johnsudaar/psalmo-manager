require "rails_helper"

RSpec.describe Edition, type: :model do
  subject(:edition) { build(:edition) }

  describe "associations" do
    it { is_expected.to have_many(:workshops).dependent(:destroy) }
    it { is_expected.to have_many(:orders).dependent(:destroy) }
    it { is_expected.to have_many(:registrations).through(:orders) }
    it { is_expected.to have_many(:staff_profiles).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:year) }
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:end_date) }
    it { is_expected.to validate_uniqueness_of(:year) }
    it { is_expected.to validate_numericality_of(:km_rate_cents).is_greater_than(0) }
  end

  describe "scopes" do
    describe ".ordered" do
      it "returns editions newest first" do
        old = create(:edition, year: 2024)
        new_ed = create(:edition, year: 2025)
        expect(Edition.ordered).to eq([ new_ed, old ])
      end
    end
  end

  describe "#current?" do
    it "returns true for the most recent edition" do
      create(:edition, year: 2024)
      latest = create(:edition, year: 2025)
      expect(latest.current?).to be true
    end

    it "returns false for an older edition" do
      older = create(:edition, year: 2024)
      create(:edition, year: 2025)
      expect(older.current?).to be false
    end
  end
end
