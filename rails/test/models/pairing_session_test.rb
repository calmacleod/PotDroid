require "test_helper"

class PairingSessionTest < ActiveSupport::TestCase
  test "issues a formatted one-time code" do
    pairing_session, raw_code = PairingSession.issue_for!(users(:one))

    assert_match(/\A[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}\z/, raw_code)
    assert pairing_session.active?
    assert pairing_session.authenticate_code(PairingSession.normalize_code(raw_code))
  end

  test "claims an active code and returns a long-lived token" do
    pairing_session, raw_code = PairingSession.issue_for!(users(:one))

    claimed_session, raw_token = PairingSession.claim!(raw_code: raw_code, device_name: "Pixel")

    assert_equal pairing_session, claimed_session
    assert claimed_session.claimed?
    assert claimed_session.api_token.present?
    assert raw_token.start_with?("pd_")
    assert_equal users(:one), ApiToken.authenticate(raw_token).user
  end

  test "does not claim expired codes" do
    pairing_session, raw_code = PairingSession.issue_for!(users(:one))
    pairing_session.update!(expires_at: 1.minute.ago)

    assert_nil PairingSession.claim!(raw_code: raw_code, device_name: "Pixel")
  end

  test "generates compact pairing payloads for scannable QR codes" do
    payload = pairing_sessions(:active).pairing_payload(
      raw_code: "ABCD-EFGH-JK23",
      api_base_url: "https://example.trycloudflare.com"
    )

    assert_equal "potdroid://pair?u=https%3A%2F%2Fexample.trycloudflare.com&c=ABCD-EFGH-JK23", payload
  end

  test "renders QR SVGs with an explicit quiet zone" do
    svg = pairing_sessions(:active).qr_svg(
      raw_code: "ABCD-EFGH-JK23",
      api_base_url: "https://example.trycloudflare.com"
    )

    assert_match(/viewBox="0 0 \d+ \d+"/, svg)
    assert_includes svg, '<rect width="100%" height="100%" fill="#fff"/>'
    assert_includes svg, "M64 64h8v8h-8z"
  end
end
