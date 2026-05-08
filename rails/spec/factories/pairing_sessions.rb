FactoryBot.define do
  factory :pairing_session do
    user
    code { "ABCD-EFGH-JK23" }
    expires_at { 15.minutes.from_now }
    claimed_at { nil }
    device_name { nil }
  end
end
