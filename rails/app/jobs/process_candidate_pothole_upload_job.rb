class ProcessCandidatePotholeUploadJob < ApplicationJob
  queue_as :default

  def perform(candidate_pothole_id)
    candidate_pothole = CandidatePothole.find(candidate_pothole_id)
    candidate_pothole.image.analyze_later if candidate_pothole.image.attached?
    candidate_pothole.begin_image_validation!
    result = PotholeDetector::ImageReliabilityValidator.new(candidate_pothole: candidate_pothole).call
    candidate_pothole.complete_image_validation!(result)
    broadcast_validation_refresh(candidate_pothole)
  rescue PotholeDetector::Unavailable, PotholeDetector::InferenceError => error
    if candidate_pothole
      candidate_pothole.fail_image_validation!(error)
      broadcast_validation_refresh(candidate_pothole)
    end
  end

  private

  def broadcast_validation_refresh(candidate_pothole)
    Turbo::StreamsChannel.broadcast_stream_to(
      candidate_pothole,
      content: %(<turbo-stream action="refresh"></turbo-stream>)
    )
  end
end
