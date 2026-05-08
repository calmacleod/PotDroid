class PollCitySubmissionStatusJob < ApplicationJob
  queue_as :default

  def perform(city_submission_id)
    submission = CitySubmission.find(city_submission_id)
    connector = CitySubmissions::Registry.fetch(submission.connector)
    result = connector.status(submission)

    submission.update!(
      status: result.status,
      external_status: result.external_status,
      last_checked_at: Time.current,
      response_payload: result.payload,
      error_message: result.status == :failed ? result.message : nil
    )
    submission.record_event!("status", payload: result.payload, message: result.message)

    submission.candidate_pothole.update!(status: :closed) if result.status == :closed
  end
end
