class Edition < ApplicationRecord
  DEFAULT_TRANSPORT_MODES = [ "Voiture", "Train", "Avion", "Bus", "Covoiturage" ].freeze
  DEFAULT_ALLOWANCE_LABELS = [ "Cachet", "Prestation", "Intervention", "Remboursement" ].freeze

  has_paper_trail skip: [ :updated_at ], skip_unchanged: true

  has_many :workshops, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :registrations, through: :orders
  has_many :staff_profiles, dependent: :destroy

  validates :name, :year, :start_date, :end_date, presence: true
  validates :year, uniqueness: true
  validates :km_rate_cents, numericality: { greater_than: 0 }

  scope :ordered, -> { order(year: :desc) }

  def transport_mode_options
    parse_option_lines(transport_modes, DEFAULT_TRANSPORT_MODES)
  end

  def allowance_label_options
    parse_option_lines(allowance_labels, DEFAULT_ALLOWANCE_LABELS)
  end

  def current?
    Edition.order(year: :desc).first == self
  end

  private

  def parse_option_lines(value, defaults)
    options = value.to_s.lines.map(&:strip).reject(&:blank?)
    options.presence || defaults
  end
end
