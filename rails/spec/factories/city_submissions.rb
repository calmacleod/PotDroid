FactoryBot.define do
  factory :city_submission do
    candidate_pothole
    connector { "ottawa_open311" }
    status { :pending }
    external_request_id { nil }
    external_status { nil }
    response_payload { {} }
    error_message { nil }
  end
end
