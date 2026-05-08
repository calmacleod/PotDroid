require 'rails_helper'

RSpec.describe ApiToken, type: :model do
  it "issues a raw token once and stores only a digest" do
    user = create(:user)

    api_token, raw_token = described_class.issue!(user: user, name: "Pixel")

    expect(raw_token).to start_with("pd_")
    expect(api_token.token_digest).to be_present
    expect(api_token.token_digest).not_to eq(raw_token)
    expect(described_class.authenticate(raw_token)).to eq(api_token)
  end
end
