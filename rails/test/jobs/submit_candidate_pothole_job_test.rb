require "test_helper"

class SubmitCandidatePotholeJobTest < ActiveJob::TestCase
  test "creates a manual-required city submission when Ottawa API key is missing" do
    candidate = candidate_potholes(:confirmed)
    candidate.city_submission&.destroy!

    SubmitCandidatePotholeJob.perform_now(candidate.id)

    submission = candidate.reload.city_submission
    assert submission.manual_required?
    assert_equal "submit", submission.city_submission_events.last.event_type
  end
end
