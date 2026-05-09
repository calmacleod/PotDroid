require "test_helper"

class ApiPairingsTest < ActionDispatch::IntegrationTest
  test "exchanges a valid pairing code for a bearer token" do
    _pairing_session, raw_code = PairingSession.issue_for!(users(:one))

    post api_v1_pairing_path, params: {
      pairing: {
        code: raw_code,
        device_name: "Pixel 9"
      }
    }

    token = json_response.dig("data", "attributes", "api_token")

    assert_response :created
    assert token.start_with?("pd_")
    assert_equal users(:one), ApiToken.authenticate(token).user
  end

  test "broadcasts a browser redirect for the claimed pairing session" do
    pairing_session, raw_code = PairingSession.issue_for!(users(:one))
    broadcasts = []

    with_stubbed_method(Turbo::StreamsChannel, :broadcast_stream_to, ->(*args, **kwargs) { broadcasts << [ args, kwargs ] }) do
      post api_v1_pairing_path, params: {
        pairing: {
          code: raw_code,
          device_name: "Pixel 9"
        }
      }
    end

    assert_equal [ [ pairing_session ], { content: %(<turbo-stream action="redirect" url="/candidate_potholes"></turbo-stream>) } ], broadcasts.last
  end

  test "rejects invalid pairing codes" do
    post api_v1_pairing_path, params: { pairing: { code: "NOPE", device_name: "Pixel" } }

    assert_response :unprocessable_content
    assert_equal "invalid_pairing_code", json_response["code"]
  end
end
