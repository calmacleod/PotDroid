class CitySubmission < ApplicationRecord
  belongs_to :candidate_pothole
  has_many :city_submission_events, dependent: :destroy

  enum :status, {
    pending: 0,
    submitted: 1,
    closed: 2,
    failed: 3,
    manual_required: 4
  }

  validates :connector, presence: true

  def record_event!(event_type, payload: {}, message: nil)
    city_submission_events.create!(event_type: event_type, payload: payload, message: message)
  end
end
