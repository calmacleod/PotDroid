class CandidatePotholeReconciliationsController < ApplicationController
  def index
    @groups = CandidatePotholeReconciliation::GroupFinder.new(Current.user.candidate_potholes).call
  end

  def create
    representative = Current.user.candidate_potholes.find(params[:representative_id])
    duplicates = Current.user.candidate_potholes.where(id: duplicate_ids).where.not(id: representative.id)

    duplicates.find_each do |duplicate|
      duplicate.mark_duplicate_of!(representative: representative, reviewer: Current.user)
    end

    redirect_to candidate_pothole_reconciliations_path, notice: "#{duplicates.size} duplicate #{"candidate".pluralize(duplicates.size)} marked."
  end

  private

  def duplicate_ids
    Array(params[:duplicate_ids]).compact_blank
  end
end
