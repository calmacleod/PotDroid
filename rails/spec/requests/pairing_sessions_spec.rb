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

  it "uses the injected API base URL for Android pairing" do
    original_url = ENV["POTDROID_API_BASE_URL"]
    ENV["POTDROID_API_BASE_URL"] = "https://dev-tunnel.trycloudflare.com"

    post pairing_sessions_path

    expect(response.body).to include("https://dev-tunnel.trycloudflare.com")
    expect(response.body).to include("u=https%3A%2F%2Fdev-tunnel.trycloudflare.com")
  ensure
    ENV["POTDROID_API_BASE_URL"] = original_url
  end
end
