require "test_helper"

class PairingSessionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "renders a QR code and pairing code for the signed-in user" do
    post pairing_sessions_path

    assert_redirected_to pairing_session_path(@user.pairing_sessions.last)

    follow_redirect!

    assert_response :ok
    assert_includes response.body, "Pair Android app"
    assert_includes response.body, "<svg"
    assert_includes response.body, "turbo-cable-stream-source"
    assert_equal 3, @user.pairing_sessions.count
  end

  test "supports refreshing the pairing page" do
    post pairing_sessions_path
    pairing_session = @user.pairing_sessions.last

    get pairing_session_path(pairing_session)

    assert_response :ok
    assert_includes response.body, "Pair Android app"
    assert_includes response.body, "<svg"
  end

  test "uses the injected API base URL for Android pairing" do
    with_potdroid_api_base_url("https://dev-tunnel.trycloudflare.com") do
      post pairing_sessions_path
      follow_redirect!
    end

    assert_includes response.body, "https://dev-tunnel.trycloudflare.com"
    assert_includes response.body, "u=https%3A%2F%2Fdev-tunnel.trycloudflare.com"
  end

  private
    def with_potdroid_api_base_url(value)
      original_url = ENV["POTDROID_API_BASE_URL"]
      ENV["POTDROID_API_BASE_URL"] = value
      yield
    ensure
      original_url.nil? ? ENV.delete("POTDROID_API_BASE_URL") : ENV["POTDROID_API_BASE_URL"] = original_url
    end
end
