FactoryBot.define do
  factory :staff_profile do
    association :person
    association :edition
    dossier_number           { nil }  # auto-assigned by callback
    transport_mode           { "Voiture" }
    km_traveled              { 150 }
    allowance_cents          { 20000 }
    supplies_cost_cents      { 4500 }
    accommodation_cost_cents { 0 }
    meals_cost_cents         { 0 }
    tickets_cost_cents       { 0 }
  end
end
