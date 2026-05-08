require "rails_helper"

RSpec.describe "Candidate pothole review", type: :request do
  let(:user) { create(:user) }
  let(:candidate) { create(:candidate_pothole, user: user) }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "lists the current user's candidate potholes" do
    candidate

    get candidate_potholes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Candidate potholes")
    expect(response.body).to include("fake-detector-v1").or include("91.0%")
  end

  it "confirms a candidate" do
    patch confirm_candidate_pothole_path(candidate)

    expect(response).to redirect_to(candidate)
    expect(candidate.reload).to be_confirmed
    expect(candidate.reviewed_by).to eq(user)
  end

  it "rejects a candidate" do
    patch reject_candidate_pothole_path(candidate)

    expect(response).to redirect_to(candidate)
    expect(candidate.reload).to be_rejected
  end
end
