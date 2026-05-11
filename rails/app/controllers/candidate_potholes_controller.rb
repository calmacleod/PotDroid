class CandidatePotholesController < ApplicationController
  before_action :set_candidate_pothole, only: %i[ show confirm reject submit validate_detector revalidate_image ]
  DISPLAY_STATUSES = %w[ review pending_review confirmed rejected submitted closed ].freeze

  def index
    @status = normalized_status
    @status_counts = visible_candidates.group(:status).count
    @review_count = @status_counts.fetch("pending_review", 0) + @status_counts.fetch("confirmed", 0)
    @candidate_potholes = filtered_candidates.with_attached_image.recent_first
  end

  def map
    @status = normalized_status
    @status_counts = visible_candidates.group(:status).count
    @review_count = @status_counts.fetch("pending_review", 0) + @status_counts.fetch("confirmed", 0)
    @candidate_potholes = filtered_candidates.with_attached_image.includes(:city_submission).recent_first
    @mapbox_access_token = ENV["MAPBOX_ACCESS_TOKEN"].to_s
  end

  def show
    @detector_validation_result = flash[:detector_validation_result]
    @detector_validation_error = flash[:detector_validation_error]
  end

  def confirm
    @candidate_pothole.confirm!(reviewer: Current.user)
    redirect_to review_return_path, notice: "Candidate pothole confirmed."
  end

  def reject
    @candidate_pothole.reject!(reviewer: Current.user)
    redirect_to review_return_path, notice: "Candidate pothole rejected."
  end

  def submit
    @candidate_pothole.confirm!(reviewer: Current.user) if @candidate_pothole.pending_review?
    SubmitCandidatePotholeJob.perform_later(@candidate_pothole.id)
    redirect_to @candidate_pothole, notice: "City submission queued."
  end

  def validate_detector
    flash[:detector_validation_result] = flash_safe_detector_validation_result(validate_attached_image)
    redirect_to @candidate_pothole, status: :see_other
  rescue PotholeDetector::Unavailable, PotholeDetector::InferenceError => error
    flash[:detector_validation_error] = error.message
    redirect_to @candidate_pothole, status: :see_other
  end

  def revalidate_image
    @candidate_pothole.request_image_revalidation!
    ProcessCandidatePotholeUploadJob.perform_later(@candidate_pothole.id)

    redirect_to @candidate_pothole, notice: "Image validation queued.", status: :see_other
  end

  private

  def normalized_status
    requested_status = params[:status].presence || "review"
    DISPLAY_STATUSES.include?(requested_status) ? requested_status : "review"
  end

  def filtered_candidates
    case @status
    when "review"
      visible_candidates.where(status: %i[ pending_review confirmed ])
    else
      visible_candidates.with_status(@status)
    end
  end

  def visible_candidates
    Current.user.candidate_potholes.where.not(status: :duplicate)
  end

  def review_return_path
    return @candidate_pothole if params[:return_to].blank?
    return params[:return_to] if params[:return_to].start_with?("/") && !params[:return_to].start_with?("//")

    @candidate_pothole
  end

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

  def flash_safe_detector_validation_result(result)
    result.slice(
      "detected",
      "confidence",
      "threshold",
      "model_version",
      "bounding_box"
    )
  end
end
