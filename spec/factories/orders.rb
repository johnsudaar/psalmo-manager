FactoryBot.define do
  factory :order do
    association :edition
    association :payer, factory: :person
    helloasso_order_id { "order-#{SecureRandom.hex(8)}" }
    order_date         { Time.current }
    status             { :confirmed }
  end
end
