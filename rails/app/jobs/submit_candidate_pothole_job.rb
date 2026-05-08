class SubmitCandidatePotholeJob < ApplicationJob
  queue_as :default

  def perform(candidate_pothole_id)
    candidate_pothole = CandidatePothole.find(candidate_pothole_id)
    return unless candidate_pothole.confirmed? || candidate_pothole.submitted?

    connector_name = ENV.fetch("CITY_CONNECTOR", CitySubmissions::Ottawa::Open311Connector::CONNECTOR_NAME)
    connector = CitySubmissions::Registry.fetch(connector_name)
    submission = candidate_pothole.city_submission || candidate_pothole.create_city_submission!(
      connector: connector_name,
      status: :pending
    )

    result = connector.submit(candidate_pothole)
    submission.update!(
      status: result.status,
      external_request_id: result.external_request_id,
      external_status: result.external_status,
      submitted_at: Time.current,
      response_payload: result.payload,
      error_message: result.status == :failed ? result.message : nil
    )
    submission.record_event!("submit", payload: result.payload, message: result.message)

    candidate_pothole.mark_submitted!(external_status: result.external_status) if result.status == :submitted
  end
end
