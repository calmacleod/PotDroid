require "rails_helper"

RSpec.describe "Pairing sessions", type: :request do
  include ActionCable::TestHelper

  let(:user) { create(:user) }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "renders a QR code and pairing code for the signed-in user" do
    post pairing_sessions_path

    expect(response).to redirect_to(pairing_session_path(user.pairing_sessions.last))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pair Android app")
    expect(response.body).to include("<svg")
    expect(response.body).to include("turbo-cable-stream-source")
    expect(user.pairing_sessions.count).to eq(1)
  end

  it "supports refreshing the pairing page" do
    post pairing_sessions_path
    pairing_session = user.pairing_sessions.last

    get pairing_session_path(pairing_session)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pair Android app")
    expect(response.body).to include("<svg")
  end

  it "uses the injected API base URL for Android pairing" do
    original_url = ENV["POTDROID_API_BASE_URL"]
    ENV["POTDROID_API_BASE_URL"] = "https://dev-tunnel.trycloudflare.com"

    post pairing_sessions_path
    follow_redirect!

    expect(response.body).to include("https://dev-tunnel.trycloudflare.com")
    expect(response.body).to include("u=https%3A%2F%2Fdev-tunnel.trycloudflare.com")
  ensure
    ENV["POTDROID_API_BASE_URL"] = original_url
  end
end
