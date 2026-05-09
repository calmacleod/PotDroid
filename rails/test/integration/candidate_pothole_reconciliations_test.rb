require "test_helper"

class CandidatePotholeReconciliationsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "shows likely duplicate candidate groups" do
    first = create_candidate_pothole!(user: @user, latitude: 45.421500, longitude: -75.697200, captured_at: Time.zone.parse("2026-05-08 12:00:00"), detector_confidence: 0.71)
    second = create_candidate_pothole!(user: @user, latitude: 45.421560, longitude: -75.697250, captured_at: Time.zone.parse("2026-05-08 12:00:45"), detector_confidence: 0.93)

    get candidate_pothole_reconciliations_path

    assert_response :ok
    assert_includes response.body, "Reconcile potholes"
    assert_includes response.body, "Likely duplicate group"
    assert_includes response.body, "Candidate ##{first.id}"
    assert_includes response.body, "Candidate ##{second.id}"
  end

  test "marks selected candidates as duplicates of the representative" do
    representative = create_candidate_pothole!(user: @user, latitude: 45.421500, longitude: -75.697200, captured_at: Time.zone.parse("2026-05-08 12:00:00"))
    duplicate = create_candidate_pothole!(user: @user, latitude: 45.421560, longitude: -75.697250, captured_at: Time.zone.parse("2026-05-08 12:00:45"))
    other_user_candidate = candidate_potholes(:other_user_pending)

    post candidate_pothole_reconciliations_path,
      params: {
        representative_id: representative.id,
        duplicate_ids: [ duplicate.id, other_user_candidate.id ]
      }

    assert_redirected_to candidate_pothole_reconciliations_path
    assert duplicate.reload.duplicate?
    assert_equal representative, duplicate.duplicate_of
    assert_equal @user, duplicate.reviewed_by
    assert other_user_candidate.reload.pending_review?
  end
end
