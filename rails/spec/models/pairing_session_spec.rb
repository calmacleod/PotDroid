require 'rails_helper'

RSpec.describe PairingSession, type: :model do
  it "issues a formatted one-time code" do
    user = create(:user)

    pairing_session, raw_code = described_class.issue_for!(user)

    expect(raw_code).to match(/\A[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}\z/)
    expect(pairing_session).to be_active
    expect(pairing_session.authenticate_code(described_class.normalize_code(raw_code))).to be_truthy
  end

  it "claims an active code and returns a long-lived token" do
    user = create(:user)
    pairing_session, raw_code = described_class.issue_for!(user)

    claimed_session, raw_token = described_class.claim!(raw_code: raw_code, device_name: "Pixel")

    expect(claimed_session).to eq(pairing_session)
    expect(claimed_session).to be_claimed
    expect(claimed_session.api_token).to be_present
    expect(raw_token).to start_with("pd_")
    expect(ApiToken.authenticate(raw_token).user).to eq(user)
  end

  it "does not claim expired codes" do
    user = create(:user)
    pairing_session, raw_code = described_class.issue_for!(user)
    pairing_session.update!(expires_at: 1.minute.ago)

    expect(described_class.claim!(raw_code: raw_code, device_name: "Pixel")).to be_nil
  end

  it "generates compact pairing payloads for scannable QR codes" do
    pairing_session = build(:pairing_session)

    payload = pairing_session.pairing_payload(
      raw_code: "ABCD-EFGH-JK23",
      api_base_url: "https://example.trycloudflare.com"
    )

    expect(payload).to eq("potdroid://pair?u=https%3A%2F%2Fexample.trycloudflare.com&c=ABCD-EFGH-JK23")
  end

  it "renders QR SVGs with an explicit quiet zone" do
    pairing_session = build(:pairing_session)

    svg = pairing_session.qr_svg(
      raw_code: "ABCD-EFGH-JK23",
      api_base_url: "https://example.trycloudflare.com"
    )

    expect(svg).to match(/viewBox="0 0 \d+ \d+"/)
    expect(svg).to include('<rect width="100%" height="100%" fill="#fff"/>')
    expect(svg).to include('M64 64h8v8h-8z')
  end
end
