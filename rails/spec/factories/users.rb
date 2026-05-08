FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "driver#{n}@example.com" }
    password { "password123" }
  end
end
