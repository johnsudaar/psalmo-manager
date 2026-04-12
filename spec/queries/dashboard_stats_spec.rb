require "rails_helper"

RSpec.describe DashboardStats do
  let(:edition) { create(:edition, start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 14)) }
  subject(:stats) { described_class.new(edition) }

  # Helper: create a registration for this edition
  def make_registration(attrs = {})
    order = create(:order, edition: edition, order_date: attrs.delete(:order_date) || Time.current)
    create(:registration, { order: order, edition: edition }.merge(attrs))
  end

  describe "#total_billetterie_cents" do
    it "sums ticket_price_cents - discount_cents for stats registrations" do
      make_registration(ticket_price_cents: 10000, discount_cents: 1000)
      make_registration(ticket_price_cents: 8000, discount_cents: 0)
      expect(stats.total_billetterie_cents).to eq(17000)
    end

    it "excludes excluded_from_stats registrations" do
      make_registration(ticket_price_cents: 10000, discount_cents: 0)
      make_registration(ticket_price_cents: 5000, discount_cents: 0, excluded_from_stats: true)
      expect(stats.total_billetterie_cents).to eq(10000)
    end

    it "returns 0 when no registrations" do
      expect(stats.total_billetterie_cents).to eq(0)
    end
  end

  describe "#total_ateliers_cents" do
    it "sums price_paid_cents for registration_workshops of stats registrations" do
      reg = make_registration
      workshop = create(:workshop, edition: edition)
      create(:registration_workshop, registration: reg, workshop: workshop, price_paid_cents: 3000)
      create(:registration_workshop, registration: reg, workshop: create(:workshop, edition: edition), price_paid_cents: 2000)
      expect(stats.total_ateliers_cents).to eq(5000)
    end

    it "excludes excluded_from_stats registrations" do
      excluded_reg = make_registration(excluded_from_stats: true)
      workshop = create(:workshop, edition: edition)
      create(:registration_workshop, registration: excluded_reg, workshop: workshop, price_paid_cents: 4000)
      expect(stats.total_ateliers_cents).to eq(0)
    end
  end

  describe "#total_revenue_cents" do
    it "sums billetterie and ateliers" do
      reg = make_registration(ticket_price_cents: 10000, discount_cents: 0)
      workshop = create(:workshop, edition: edition)
      create(:registration_workshop, registration: reg, workshop: workshop, price_paid_cents: 3000)
      expect(stats.total_revenue_cents).to eq(13000)
    end
  end

  describe "#total_participants" do
    it "counts stats registrations" do
      make_registration
      make_registration
      make_registration(excluded_from_stats: true)
      expect(stats.total_participants).to eq(2)
    end
  end

  describe "#participants_enfant / #participants_adulte" do
    it "counts by age category (excluding excluded_from_stats)" do
      make_registration(age_category: :enfant)
      make_registration(age_category: :enfant)
      make_registration(age_category: :adulte)
      make_registration(age_category: :enfant, excluded_from_stats: true)
      expect(stats.participants_enfant).to eq(2)
      expect(stats.participants_adulte).to eq(1)
    end
  end

  describe "#unaccompanied_minors_count" do
    it "counts all registrations with is_unaccompanied_minor regardless of exclusion" do
      make_registration(is_unaccompanied_minor: true)
      make_registration(is_unaccompanied_minor: true, excluded_from_stats: true)
      make_registration(is_unaccompanied_minor: false)
      expect(stats.unaccompanied_minors_count).to eq(2)
    end
  end

  describe "#conflicts_count" do
    it "counts registrations with has_conflict" do
      make_registration(has_conflict: true)
      make_registration(has_conflict: false)
      expect(stats.conflicts_count).to eq(1)
    end
  end

  describe "#workshop_fill_rates" do
    it "returns fill rate data for workshops in the edition" do
      w = create(:workshop, edition: edition, capacity: 4)
      reg = make_registration
      create(:registration_workshop, registration: reg, workshop: w, price_paid_cents: 0)

      rates = stats.workshop_fill_rates
      expect(rates.size).to eq(1)
      expect(rates.first[:workshop]).to eq(w)
      expect(rates.first[:enrolled]).to eq(1)
      expect(rates.first[:fill_rate]).to eq(25.0)
    end

    it "excludes excluded_from_stats registrations from fill count" do
      w = create(:workshop, edition: edition, capacity: 4)
      reg = make_registration(excluded_from_stats: true)
      create(:registration_workshop, registration: reg, workshop: w, price_paid_cents: 0)
      expect(stats.workshop_fill_rates.first[:enrolled]).to eq(0)
    end

    it "returns nil fill_rate when capacity is nil" do
      create(:workshop, edition: edition, capacity: nil)
      expect(stats.workshop_fill_rates.first[:fill_rate]).to be_nil
    end
  end

  describe "#age_distribution" do
    it "returns a hash of age_category => count for stats registrations" do
      make_registration(age_category: :enfant)
      make_registration(age_category: :enfant)
      make_registration(age_category: :adulte)
      dist = stats.age_distribution
      expect(dist["enfant"]).to eq(2)
      expect(dist["adulte"]).to eq(1)
    end
  end

  describe "#recent_registrations" do
    it "returns at most 5 registrations ordered by order_date desc" do
      6.times { |i| make_registration(order_date: i.days.ago) }
      expect(stats.recent_registrations.size).to eq(5)
    end

    it "returns registrations from most recent first" do
      old = make_registration(order_date: 10.days.ago)
      recent = make_registration(order_date: 1.day.ago)
      results = stats.recent_registrations
      expect(results.first.order.order_date).to be > results.last.order.order_date
    end
  end
end
