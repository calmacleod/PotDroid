require "test_helper"

class CandidatePotholeTest < ActiveSupport::TestCase
  test "starts pending review with an attached image" do
    candidate = candidate_potholes(:pending)

    assert candidate.pending_review?
    assert candidate.image.attached?
  end

  test "records reviewer and timestamp when confirmed" do
    candidate = candidate_potholes(:pending)
    reviewer = users(:two)

    candidate.confirm!(reviewer: reviewer)

    assert candidate.confirmed?
    assert_equal reviewer, candidate.reviewed_by
    assert candidate.reviewed_at.present?
  end

  test "records duplicate candidates against a representative pothole" do
    reviewer = users(:two)
    representative = candidate_potholes(:pending)
    duplicate = create_candidate_pothole!(user: representative.user, latitude: "45.4216")

    duplicate.mark_duplicate_of!(representative: representative, reviewer: reviewer)

    assert duplicate.duplicate?
    assert_equal representative, duplicate.duplicate_of
    assert_equal reviewer, duplicate.reviewed_by
    assert duplicate.reviewed_at.present?
  end

  test "does not allow duplicates across users" do
    duplicate = candidate_potholes(:pending)
    duplicate.duplicate_of = candidate_potholes(:other_user_pending)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:duplicate_of], "must belong to the same user"
  end

  test "does not allow a candidate to be a duplicate of itself" do
    candidate = candidate_potholes(:pending)
    candidate.duplicate_of = candidate

    assert_not candidate.valid?
    assert_includes candidate.errors[:duplicate_of], "cannot be itself"
  end
end
