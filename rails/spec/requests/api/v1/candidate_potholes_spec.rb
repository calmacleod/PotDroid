require "rails_helper"

RSpec.describe "API candidate potholes", type: :request do
  let(:user) { create(:user) }
  let(:token_pair) { ApiToken.issue!(user: user, name: "Android") }
  let(:raw_token) { token_pair.last }
  let(:headers) { { "Authorization" => "Bearer #{raw_token}" } }
  let(:image) { fixture_file_upload("pothole.png", "image/png") }

  describe "POST /api/v1/candidate_potholes" do
    it "creates an authenticated candidate pothole upload" do
      expect do
        post api_v1_candidate_potholes_path,
          params: {
            candidate_pothole: {
              image: image,
              latitude: "45.4215",
              longitude: "-75.6972",
              detector_confidence: "0.88",
              detector_model_version: "fake-detector-v1",
              captured_at: "2026-05-08T12:00:00Z",
              bounding_box: { left: 0.1, top: 0.2, right: 0.3, bottom: 0.4 }
            }
          },
          headers: headers
      end.to change(user.candidate_potholes, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(user.candidate_potholes.last.image).to be_attached
      expect(JSON.parse(response.body).dig("data", "attributes", "status")).to eq("pending_review")
    end

    it "rejects missing tokens" do
      post api_v1_candidate_potholes_path, params: { candidate_pothole: {} }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/candidate_potholes/:id" do
    it "returns only the current user's candidate" do
      candidate = create(:candidate_pothole, user: user)

      get api_v1_candidate_pothole_path(candidate), headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "id")).to eq(candidate.id)
    end
  end
end
