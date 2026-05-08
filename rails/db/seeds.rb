driver = User.find_or_create_by!(email_address: "driver@example.com") do |user|
  user.password = "password123"
end

candidate = driver.candidate_potholes.find_or_initialize_by(captured_at: Time.zone.parse("2026-05-08 12:00:00 UTC"))
candidate.assign_attributes(
  latitude: 45.4215,
  longitude: -75.6972,
  detector_confidence: 0.91,
  detector_model_version: "fake-detector-v1",
  bounding_box: { left: 0.1, top: 0.2, right: 0.4, bottom: 0.5 }
)
unless candidate.image.attached?
  candidate.image.attach(
    io: StringIO.new("seed pothole image"),
    filename: "seed-pothole.jpg",
    content_type: "image/jpeg"
  )
end
candidate.save!

unless driver.api_tokens.exists?(name: "Seed Android token")
  _api_token, raw_token = ApiToken.issue!(user: driver, name: "Seed Android token")
  puts "Seed Android token: #{raw_token}"
end
