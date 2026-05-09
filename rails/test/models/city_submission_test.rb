require "test_helper"

class CitySubmissionTest < ActiveSupport::TestCase
  test "records connector events" do
    submission = city_submissions(:pending)

    event = submission.record_event!("submit", payload: { "id" => "123" }, message: "Submitted")

    assert event.persisted?
    assert_equal({ "id" => "123" }, event.payload)
    assert_equal "Submitted", event.message
  end
end
