FactoryBot.define do
  factory :candidate_pothole do
    user
    status { :pending_review }
    latitude { "45.4215" }
    longitude { "-75.6972" }
    heading { "180.0" }
    speed { "12.5" }
    detector_confidence { "0.91" }
    detector_model_version { "fake-detector-v1" }
    bounding_box { { "left" => 0.1, "top" => 0.2, "right" => 0.4, "bottom" => 0.5 } }
    captured_at { Time.zone.parse("2026-05-08 08:45:29") }

    after(:build) do |candidate|
      candidate.image.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/pothole.png")),
        filename: "pothole.png",
        content_type: "image/png"
      )
    end
  end
end
