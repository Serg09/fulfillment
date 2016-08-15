FactoryGirl.define do
  factory :order, aliases: [:new_order] do
    transient do
      item_count 0
    end
    client
    client_order_id { Faker::Number.hexadecimal(12) }
    order_date { Faker::Date.backward(5) }
    customer_name { Faker::Name.name }
    address_1 { Faker::Address.street_address }
    address_2 { Faker::Address.secondary_address }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    postal_code { Faker::Address.postcode }
    country_code { Faker::Address.country_code }
    telephone { Faker::PhoneNumber.phone_number }

    after(:create) do |order, evaluator|
      (1..(evaluator.item_count)).each do |i|
        order.items << FactoryGirl.create(:order_item, order: order)
      end
    end

    factory :exported_order do
      status 'exported'
    end

    factory :processing_order do
      status 'processing'
    end
  end
end
