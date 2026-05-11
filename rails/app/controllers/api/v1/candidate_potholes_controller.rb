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
        permitted_params = params.require(:candidate_pothole).permit(
          :image,
          :latitude,
          :longitude,
          :heading,
          :speed,
          :detector_confidence,
          :detector_model_version,
          :captured_at,
          :accelerometer_data,
          bounding_box: {}
        )
        permitted_params[:accelerometer_data] = parsed_accelerometer_data(permitted_params[:accelerometer_data])
        permitted_params
      end

      def parsed_accelerometer_data(value)
        return if value.blank?
        return value unless value.is_a?(String)

        JSON.parse(value)
      rescue JSON::ParserError
        raise ActionController::BadRequest, "accelerometer_data must be valid JSON"
      end
    end
  end
end
