require "rails_helper"

RSpec.describe CitySubmissions::Ottawa::Open311Connector do
  it "returns a manual packet without an Ottawa API key" do
    candidate = create(:candidate_pothole)

    result = described_class.new.submit(candidate)

    expect(result.status).to eq(:manual_required)
    expect(result.payload[:photo_limit_mb]).to eq(6)
    expect(result.payload[:latitude]).to eq(candidate.latitude.to_s)
  end
end
