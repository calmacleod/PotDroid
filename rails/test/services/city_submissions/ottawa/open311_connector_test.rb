require "test_helper"

class CitySubmissions::Ottawa::Open311ConnectorTest < ActiveSupport::TestCase
  test "returns a manual packet without an Ottawa API key" do
    candidate = candidate_potholes(:pending)

    result = CitySubmissions::Ottawa::Open311Connector.new.submit(candidate)

    assert_equal :manual_required, result.status
    assert_equal 6, result.payload[:photo_limit_mb]
    assert_equal candidate.latitude.to_s, result.payload[:latitude]
  end
end
