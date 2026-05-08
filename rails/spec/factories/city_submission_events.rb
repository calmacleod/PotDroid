FactoryBot.define do
  factory :city_submission_event do
    city_submission
    event_type { "submit" }
    payload { {} }
    message { "queued" }
  end
end
