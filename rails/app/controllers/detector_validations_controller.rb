class DetectorValidationsController < ApplicationController
  def new
  end

  def create
    image = uploaded_image
    @detector_validation_image_data_url = image_data_url(image)
    @detector_validation_result = PotholeDetector::TfliteValidator.new(image: image, threshold: detector_threshold).call

    render :new
  rescue PotholeDetector::Unavailable, PotholeDetector::InferenceError => error
    @detector_validation_error = error.message
    render :new, status: :unprocessable_content
  end

  private

  def uploaded_image
    image = params.dig(:detector_validation, :image)
    raise PotholeDetector::InferenceError, "choose an image to validate" if image.blank?

    image
  end

  def detector_threshold
    threshold = params.dig(:detector_validation, :threshold)
    return PotholeDetector::TfliteValidator::DEFAULT_THRESHOLD if threshold.blank?

    threshold.to_f
  end

  def image_data_url(image)
    image.rewind
    bytes = image.read
    image.rewind

    "data:#{image.content_type};base64,#{Base64.strict_encode64(bytes)}"
  end
end
