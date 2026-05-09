FactoryBot.define do
  factory :staff_advance do
    association :staff_profile
    date         { Date.today - 30 }
    amount_cents { 5000 }
    comment      { "Acompte initial" }
  end
end
