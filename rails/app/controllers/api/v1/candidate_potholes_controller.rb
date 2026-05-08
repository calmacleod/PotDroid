module Api
  module V1
    class CandidatePotholesController < BaseController
      def create
        candidate = Current.user.candidate_potholes.create!(candidate_params)
        ProcessCandidatePotholeUploadJob.perform_later(candidate.id)

        render json: CandidatePotholeSerializer.new(candidate).as_json, status: :created
      end

      def show
        candidate = Current.user.candidate_potholes.find(params[:id])

        render json: CandidatePotholeSerializer.new(candidate).as_json
      end

      private

      def candidate_params
        params.require(:candidate_pothole).permit(
          :image,
          :latitude,
          :longitude,
          :heading,
          :speed,
          :detector_confidence,
          :detector_model_version,
          :captured_at,
          bounding_box: {}
        )
      end
    end
  end
end
