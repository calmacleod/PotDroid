require "rails_helper"

RSpec.describe CandidatePotholeReconciliation::GroupFinder do
  it "groups pending candidates captured close together near the same coordinates" do
    user = create(:user)
    first = create(:candidate_pothole, user: user, latitude: 45.421500, longitude: -75.697200, captured_at: Time.zone.parse("2026-05-08 12:00:00"), detector_confidence: 0.71)
    second = create(:candidate_pothole, user: user, latitude: 45.421560, longitude: -75.697250, captured_at: Time.zone.parse("2026-05-08 12:00:45"), detector_confidence: 0.93)
    create(:candidate_pothole, user: user, latitude: 45.423000, longitude: -75.699000, captured_at: Time.zone.parse("2026-05-08 12:00:50"))

    groups = described_class.new(user.candidate_potholes).call

    expect(groups.size).to eq(1)
    expect(groups.first.candidates).to contain_exactly(first, second)
    expect(groups.first.representative).to eq(second)
  end

  it "does not group candidates outside the time window" do
    user = create(:user)
    create(:candidate_pothole, user: user, latitude: 45.421500, longitude: -75.697200, captured_at: Time.zone.parse("2026-05-08 12:00:00"))
    create(:candidate_pothole, user: user, latitude: 45.421510, longitude: -75.697210, captured_at: Time.zone.parse("2026-05-08 12:05:00"))

    expect(described_class.new(user.candidate_potholes).call).to be_empty
  end

  it "ignores candidates already marked as duplicates" do
    user = create(:user)
    representative = create(:candidate_pothole, user: user, latitude: 45.421500, longitude: -75.697200, captured_at: Time.zone.parse("2026-05-08 12:00:00"))
    duplicate = create(:candidate_pothole, user: user, latitude: 45.421510, longitude: -75.697210, captured_at: Time.zone.parse("2026-05-08 12:00:10"))
    duplicate.mark_duplicate_of!(representative: representative, reviewer: user)

    expect(described_class.new(user.candidate_potholes).call).to be_empty
  end
end
