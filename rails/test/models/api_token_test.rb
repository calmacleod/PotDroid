require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "issues a raw token once and stores only a digest" do
    api_token, raw_token = ApiToken.issue!(user: users(:one), name: "Pixel")

    assert raw_token.start_with?("pd_")
    assert api_token.token_digest.present?
    assert_not_equal raw_token, api_token.token_digest
    assert_equal api_token, ApiToken.authenticate(raw_token)
  end
end
