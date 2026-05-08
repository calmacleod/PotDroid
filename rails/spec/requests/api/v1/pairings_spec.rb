require "rails_helper"

RSpec.describe "API pairings", type: :request do
  describe "POST /api/v1/pairing" do
    it "exchanges a valid pairing code for a bearer token" do
      user = create(:user)
      _pairing_session, raw_code = PairingSession.issue_for!(user)

      post api_v1_pairing_path, params: {
        pairing: {
          code: raw_code,
          device_name: "Pixel 9"
        }
      }

      body = JSON.parse(response.body)
      token = body.dig("data", "attributes", "api_token")

      expect(response).to have_http_status(:created)
      expect(token).to start_with("pd_")
      expect(ApiToken.authenticate(token).user).to eq(user)
    end

    it "rejects invalid pairing codes" do
      post api_v1_pairing_path, params: { pairing: { code: "NOPE", device_name: "Pixel" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["code"]).to eq("invalid_pairing_code")
    end
  end
end
