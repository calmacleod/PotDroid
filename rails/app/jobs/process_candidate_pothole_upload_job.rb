class ProcessCandidatePotholeUploadJob < ApplicationJob
  queue_as :default

  def perform(candidate_pothole_id)
    candidate_pothole = CandidatePothole.find(candidate_pothole_id)
    candidate_pothole.image.analyze_later if candidate_pothole.image.attached?
  end
end
