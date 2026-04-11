FactoryBot.define do
  factory :edition do
    sequence(:year) { |n| 2020 + n }
    name          { "Psalmodia #{year}" }
    start_date    { Date.new(year, 7, 1) }
    end_date      { Date.new(year, 7, 7) }
    helloasso_form_slug { "psalmodia-#{year}" }
    km_rate_cents { 33 }
  end
end
