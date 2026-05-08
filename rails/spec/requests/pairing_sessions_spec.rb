require "rails_helper"

RSpec.describe "Pairing sessions", type: :request do
  let(:user) { create(:user) }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "renders a QR code and pairing code for the signed-in user" do
    post pairing_sessions_path

    expect(response).to have_http_status(:created)
    expect(response.body).to include("Pair Android app")
    expect(response.body).to include("<svg")
    expect(user.pairing_sessions.count).to eq(1)
  end
end
