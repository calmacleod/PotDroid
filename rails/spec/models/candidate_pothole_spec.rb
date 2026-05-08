require 'rails_helper'

RSpec.describe CandidatePothole, type: :model do
  it "starts pending review with an attached image" do
    candidate = create(:candidate_pothole)

    expect(candidate).to be_pending_review
    expect(candidate.image).to be_attached
  end

  it "records reviewer and timestamp when confirmed" do
    candidate = create(:candidate_pothole)
    reviewer = create(:user)

    candidate.confirm!(reviewer: reviewer)

    expect(candidate).to be_confirmed
    expect(candidate.reviewed_by).to eq(reviewer)
    expect(candidate.reviewed_at).to be_present
  end
end
