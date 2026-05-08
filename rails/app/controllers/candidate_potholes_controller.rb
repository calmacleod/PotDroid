class CandidatePotholesController < ApplicationController
  before_action :set_candidate_pothole, only: %i[ show confirm reject submit validate_detector ]

  def index
    @status = params[:status]
    @candidate_potholes = Current.user.candidate_potholes.with_attached_image.with_status(@status).recent_first
    @status_counts = Current.user.candidate_potholes.group(:status).count
    @candidate_total = @status_counts.values.sum
  end

  def show
    @detector_validation_result = flash[:detector_validation_result]
    @detector_validation_error = flash[:detector_validation_error]
  end

  def confirm
    @candidate_pothole.confirm!(reviewer: Current.user)
    redirect_to @candidate_pothole, notice: "Candidate pothole confirmed."
  end

  def reject
    @candidate_pothole.reject!(reviewer: Current.user)
    redirect_to @candidate_pothole, notice: "Candidate pothole rejected."
  end

  def submit
    @candidate_pothole.confirm!(reviewer: Current.user) if @candidate_pothole.pending_review?
    SubmitCandidatePotholeJob.perform_later(@candidate_pothole.id)
    redirect_to @candidate_pothole, notice: "City submission queued."
  end

  def validate_detector
    flash[:detector_validation_result] = validate_attached_image
    redirect_to @candidate_pothole, status: :see_other
  rescue PotholeDetector::Unavailable, PotholeDetector::InferenceError => error
    flash[:detector_validation_error] = error.message
    redirect_to @candidate_pothole, status: :see_other
  end

  private

  def set_candidate_pothole
    @candidate_pothole = Current.user.candidate_potholes.find(params[:id])
  end

  def validate_attached_image
    raise PotholeDetector::InferenceError, "candidate has no image attached" unless @candidate_pothole.image.attached?

    Tempfile.create([ "candidate-pothole-#{@candidate_pothole.id}", @candidate_pothole.image.filename.extension_with_delimiter ]) do |file|
      file.binmode
      file.write(@candidate_pothole.image.download)
      file.flush

      PotholeDetector::TfliteValidator.new(image: file).call
    end
  end

end
