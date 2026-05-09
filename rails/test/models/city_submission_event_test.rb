require "test_helper"

class CitySubmissionEventTest < ActiveSupport::TestCase
  test "requires an event type" do
    event = city_submission_events(:queued)
    event.event_type = nil

    assert_not event.valid?
  end
end
