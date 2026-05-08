require "rails_helper"

RSpec.describe "Candidate pothole reconciliations", type: :request do
  let(:user) { create(:user) }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "shows likely duplicate candidate groups" do
    first = create(:candidate_pothole, user: user, latitude: 45.421500, longitude: -75.697200, captured_at: Time.zone.parse("2026-05-08 12:00:00"), detector_confidence: 0.71)
    second = create(:candidate_pothole, user: user, latitude: 45.421560, longitude: -75.697250, captured_at: Time.zone.parse("2026-05-08 12:00:45"), detector_confidence: 0.93)

    get candidate_pothole_reconciliations_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Reconcile potholes")
    expect(response.body).to include("Likely duplicate group")
    expect(response.body).to include("Candidate ##{first.id}")
    expect(response.body).to include("Candidate ##{second.id}")
  end

  it "marks selected candidates as duplicates of the representative" do
    representative = create(:candidate_pothole, user: user, latitude: 45.421500, longitude: -75.697200, captured_at: Time.zone.parse("2026-05-08 12:00:00"))
    duplicate = create(:candidate_pothole, user: user, latitude: 45.421560, longitude: -75.697250, captured_at: Time.zone.parse("2026-05-08 12:00:45"))
    other_user_candidate = create(:candidate_pothole)

    post candidate_pothole_reconciliations_path,
      params: {
        representative_id: representative.id,
        duplicate_ids: [ duplicate.id, other_user_candidate.id ]
      }

    expect(response).to redirect_to(candidate_pothole_reconciliations_path)
    expect(duplicate.reload).to be_duplicate
    expect(duplicate.duplicate_of).to eq(representative)
    expect(duplicate.reviewed_by).to eq(user)
    expect(other_user_candidate.reload).to be_pending_review
  end
end
