require "test_helper"

class CandidatePotholeReconciliation::GroupFinderTest < ActiveSupport::TestCase
  test "groups pending candidates captured close together near the same coordinates" do
    user = users(:one)
    first = create_candidate_pothole!(user: user, latitude: 45.421500, longitude: -75.697200, captured_at: Time.zone.parse("2026-05-08 12:00:00"), detector_confidence: 0.71)
    second = create_candidate_pothole!(user: user, latitude: 45.421560, longitude: -75.697250, captured_at: Time.zone.parse("2026-05-08 12:00:45"), detector_confidence: 0.93)
    create_candidate_pothole!(user: user, latitude: 45.423000, longitude: -75.699000, captured_at: Time.zone.parse("2026-05-08 12:00:50"))

    groups = CandidatePotholeReconciliation::GroupFinder.new(user.candidate_potholes).call

    assert_equal 1, groups.size
    assert_equal [ first, second ].sort_by(&:id), groups.first.candidates.sort_by(&:id)
    assert_equal second, groups.first.representative
  end

  test "does not group candidates outside the time window" do
    user = users(:one)
    create_candidate_pothole!(user: user, latitude: 45.421500, longitude: -75.697200, captured_at: Time.zone.parse("2026-05-08 12:00:00"))
    create_candidate_pothole!(user: user, latitude: 45.421510, longitude: -75.697210, captured_at: Time.zone.parse("2026-05-08 12:05:00"))

    assert_empty CandidatePotholeReconciliation::GroupFinder.new(user.candidate_potholes).call
  end

  test "ignores candidates already marked as duplicates" do
    user = users(:one)
    representative = create_candidate_pothole!(user: user, latitude: 45.421500, longitude: -75.697200, captured_at: Time.zone.parse("2026-05-08 12:00:00"))
    duplicate = create_candidate_pothole!(user: user, latitude: 45.421510, longitude: -75.697210, captured_at: Time.zone.parse("2026-05-08 12:00:10"))
    duplicate.mark_duplicate_of!(representative: representative, reviewer: user)

    assert_empty CandidatePotholeReconciliation::GroupFinder.new(user.candidate_potholes).call
  end
end
