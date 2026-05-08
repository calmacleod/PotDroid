require "rails_helper"

RSpec.describe SubmitCandidatePotholeJob, type: :job do
  it "creates a manual-required city submission when Ottawa API key is missing" do
    candidate = create(:candidate_pothole, status: :confirmed)

    described_class.perform_now(candidate.id)

    submission = candidate.reload.city_submission
    expect(submission).to be_manual_required
    expect(submission.city_submission_events.last.event_type).to eq("submit")
  end
end
