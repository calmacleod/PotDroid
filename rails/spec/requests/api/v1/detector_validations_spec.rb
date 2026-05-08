require "rails_helper"

RSpec.describe "API detector validations", type: :request do
  let(:user) { create(:user) }
  let(:token_pair) { ApiToken.issue!(user: user, name: "Detector validation") }
  let(:raw_token) { token_pair.last }
  let(:headers) { { "Authorization" => "Bearer #{raw_token}" } }
  let(:image) { fixture_file_upload("pothole.png", "image/png") }

  describe "POST /api/v1/detector_validation" do
    it "returns the local detector result for an uploaded image" do
      detector_result = {
        "detected" => true,
        "confidence" => 0.82,
        "threshold" => 0.25,
        "model_version" => "pot-yolo-int8-780aff5",
        "bounding_box" => {
          "left" => 0.1,
          "top" => 0.2,
          "right" => 0.4,
          "bottom" => 0.5
        },
        "detections" => []
      }

      allow(PotholeDetector::TfliteValidator).to receive(:new).and_return(instance_double(PotholeDetector::TfliteValidator, call: detector_result))

      post api_v1_detector_validation_path,
        params: { image: image, threshold: "0.65" },
        headers: headers

      expect(PotholeDetector::TfliteValidator).to have_received(:new).with(image: kind_of(ActionDispatch::Http::UploadedFile), threshold: 0.65)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(detector_result)
    end

    it "rejects requests without an image" do
      post api_v1_detector_validation_path, headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to include("code" => "bad_request")
    end

    it "returns unavailable when the local detector runtime is missing" do
      allow(PotholeDetector::TfliteValidator).to receive(:new).and_raise(PotholeDetector::Unavailable, "install ai-edge-litert")

      post api_v1_detector_validation_path,
        params: { image: image },
        headers: headers

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)).to include(
        "code" => "detector_unavailable",
        "error" => "install ai-edge-litert"
      )
    end

    it "returns unprocessable when local inference fails" do
      allow(PotholeDetector::TfliteValidator).to receive(:new).and_raise(PotholeDetector::InferenceError, "bad image")

      post api_v1_detector_validation_path,
        params: { image: image },
        headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)).to include(
        "code" => "detector_inference_failed",
        "error" => "bad image"
      )
    end
  end
end
