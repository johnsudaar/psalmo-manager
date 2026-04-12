class DashboardStats
  def initialize(edition)
    @edition = edition
  end

  # Revenue
  def total_billetterie_cents
    stats_registrations.sum("ticket_price_cents - discount_cents")
  end

  def total_ateliers_cents
    RegistrationWorkshop
      .joins(:registration)
      .merge(stats_registrations)
      .sum(:price_paid_cents)
  end

  def total_revenue_cents
    total_billetterie_cents + total_ateliers_cents
  end

  # Participant counts
  def total_participants
    stats_registrations.count
  end

  def participants_enfant
    stats_registrations.enfant.count
  end

  def participants_adulte
    stats_registrations.adulte.count
  end

  # Unaccompanied minors
  def unaccompanied_minors_count
    @edition.registrations.unaccompanied_minors.count
  end

  # Conflict count
  def conflicts_count
    @edition.registrations.with_conflicts.count
  end

  # Workshop fill rates — array of hashes for display
  def workshop_fill_rates
    @edition.workshops.order(:time_slot, :name).map do |w|
      enrolled = w.registration_workshops.joins(:registration).merge(stats_registrations).count
      {
        workshop: w,
        enrolled: enrolled,
        capacity: w.capacity,
        fill_rate: w.capacity&.positive? ? (enrolled.to_f / w.capacity * 100).round(1) : nil
      }
    end
  end

  # Weekly registration cadence — returns hash { week_start_date => count }
  def weekly_cadence
    stats_registrations
      .joins(:order)
      .where.not(orders: { order_date: nil })
      .group_by_week("orders.order_date", format: "%Y-%m-%d")
      .count
  end

  # Age distribution — returns { "enfant" => N, "adulte" => N }
  def age_distribution
    stats_registrations
      .group(:age_category)
      .count
      .transform_keys { |k| Registration.age_categories.key(k) || k.to_s }
  end

  # Last 5 registrations (most recent by order_date)
  def recent_registrations
    @edition.registrations
      .joins(:order, :person)
      .order("orders.order_date DESC")
      .limit(5)
      .includes(:person, order: {})
  end

  private

  def stats_registrations
    @edition.registrations.for_stats
  end
end
