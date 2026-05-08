require 'rails_helper'

RSpec.describe CitySubmission, type: :model do
  it "records connector events" do
    submission = create(:city_submission)

    event = submission.record_event!("submit", payload: { "id" => "123" }, message: "Submitted")

    expect(event).to be_persisted
    expect(event.payload).to eq("id" => "123")
    expect(event.message).to eq("Submitted")
  end
end
