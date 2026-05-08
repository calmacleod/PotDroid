module Api
  module V1
    class DetectorValidationsController < BaseController
      rescue_from PotholeDetector::Unavailable, with: :detector_unavailable
      rescue_from PotholeDetector::InferenceError, with: :detector_inference_failed

      def create
        image = params.require(:image)
        result = PotholeDetector::TfliteValidator.new(image: image, threshold: threshold).call

        render json: result
      end

      private

      def detector_unavailable(exception)
        render json: { error: exception.message, code: "detector_unavailable" }, status: :service_unavailable
      end

      def detector_inference_failed(exception)
        render json: { error: exception.message, code: "detector_inference_failed" }, status: :unprocessable_content
      end

      def threshold
        Float(params.fetch(:threshold, PotholeDetector::TfliteValidator::DEFAULT_THRESHOLD))
      rescue ArgumentError, TypeError
        raise ActionController::ParameterMissing, "threshold"
      end
    end
  end
end
