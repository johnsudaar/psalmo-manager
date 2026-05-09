FactoryBot.define do
  factory :staff_payment do
    association :staff_profile
    date         { Date.today }
    amount_cents { 20000 }
    comment      { "Virement final" }
  end
end
