class Order < ApplicationRecord
  has_paper_trail skip: [ :updated_at ], skip_unchanged: true

  belongs_to :edition
  belongs_to :payer, class_name: "Person", foreign_key: :payer_id, optional: true
  has_many :registrations, dependent: :destroy

  enum :status, { pending: 0, confirmed: 1, cancelled: 2, refunded: 3 }

  validates :helloasso_order_id, presence: true, uniqueness: true
  validates :order_date, :status, presence: true
end
