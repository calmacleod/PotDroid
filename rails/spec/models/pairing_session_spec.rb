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
end
