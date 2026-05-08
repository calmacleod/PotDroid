class CandidatePotholeSerializer
  include Rails.application.routes.url_helpers

  def initialize(candidate_pothole)
    @candidate_pothole = candidate_pothole
  end

  def as_json(*)
    {
      data: {
        id: @candidate_pothole.id,
        type: "candidate_pothole",
        attributes: {
          status: @candidate_pothole.status,
          latitude: @candidate_pothole.latitude.to_f,
          longitude: @candidate_pothole.longitude.to_f,
          detector_confidence: @candidate_pothole.detector_confidence.to_f,
          detector_model_version: @candidate_pothole.detector_model_version,
          bounding_box: @candidate_pothole.bounding_box,
          captured_at: @candidate_pothole.captured_at&.iso8601,
          reviewed_at: @candidate_pothole.reviewed_at&.iso8601,
          submitted_at: @candidate_pothole.submitted_at&.iso8601,
          image_url: image_url,
          city_submission: city_submission
        }
      }
    }
  end

  private

  def image_url
    return unless @candidate_pothole.image.attached?

    rails_blob_path(@candidate_pothole.image, only_path: true)
  end

  def city_submission
    submission = @candidate_pothole.city_submission
    return unless submission

    {
      status: submission.status,
      connector: submission.connector,
      external_request_id: submission.external_request_id,
      external_status: submission.external_status,
      last_checked_at: submission.last_checked_at&.iso8601
    }
  end
end
