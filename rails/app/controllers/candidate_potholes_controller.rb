class CandidatePotholesController < ApplicationController
  before_action :set_candidate_pothole, only: %i[ show confirm reject submit ]

  def index
    @status = params[:status]
    @candidate_potholes = Current.user.candidate_potholes.with_attached_image.with_status(@status).recent_first
  end

  def show
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

  private

  def set_candidate_pothole
    @candidate_pothole = Current.user.candidate_potholes.find(params[:id])
  end
end
