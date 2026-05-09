FactoryBot.define do
  factory :registration_workshop do
    association :registration
    association :workshop
    price_paid_cents { 0 }
    is_override      { false }
  end
end
