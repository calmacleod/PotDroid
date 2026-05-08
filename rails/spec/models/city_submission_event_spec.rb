require 'rails_helper'

RSpec.describe CitySubmissionEvent, type: :model do
  it "requires an event type" do
    event = build(:city_submission_event, event_type: nil)

    expect(event).not_to be_valid
  end
end
