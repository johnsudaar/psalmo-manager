FactoryBot.define do
  factory :person do
    first_name    { Faker::Name.first_name }
    last_name     { Faker::Name.last_name }
    email         { Faker::Internet.unique.email }
    phone         { Faker::PhoneNumber.phone_number }
    date_of_birth { Faker::Date.birthday(min_age: 8, max_age: 60) }
  end
end
