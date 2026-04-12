FactoryBot.define do
  factory :registration do
    association :order
    association :person
    edition              { order.edition }
    helloasso_ticket_id  { "ticket-#{SecureRandom.hex(8)}" }
    age_category         { :adulte }
    tariff_label         { "Plein tarif" }
    ticket_price_cents   { 10000 }
    discount_cents       { 0 }
    has_conflict         { false }
  end
end
