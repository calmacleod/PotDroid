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

  it "records duplicate candidates against a representative pothole" do
    reviewer = create(:user)
    representative = create(:candidate_pothole)
    duplicate = create(:candidate_pothole, user: representative.user)

    duplicate.mark_duplicate_of!(representative: representative, reviewer: reviewer)

    expect(duplicate).to be_duplicate
    expect(duplicate.duplicate_of).to eq(representative)
    expect(duplicate.reviewed_by).to eq(reviewer)
    expect(duplicate.reviewed_at).to be_present
  end

  it "does not allow duplicates across users" do
    duplicate = create(:candidate_pothole)
    other_candidate = create(:candidate_pothole)

    duplicate.duplicate_of = other_candidate

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:duplicate_of]).to include("must belong to the same user")
  end

  it "does not allow a candidate to be a duplicate of itself" do
    candidate = create(:candidate_pothole)

    candidate.duplicate_of = candidate

    expect(candidate).not_to be_valid
    expect(candidate.errors[:duplicate_of]).to include("cannot be itself")
  end
end
