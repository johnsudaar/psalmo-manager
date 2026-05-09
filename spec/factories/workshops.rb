FactoryBot.define do
  factory :workshop do
    association :edition
    name      { Faker::Lorem.unique.word.upcase }
    time_slot { :matin }
    capacity  { 20 }
  end
end
