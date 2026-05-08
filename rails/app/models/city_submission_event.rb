class CitySubmissionEvent < ApplicationRecord
  belongs_to :city_submission

  validates :event_type, presence: true
end
