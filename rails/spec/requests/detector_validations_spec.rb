require "rails_helper"

RSpec.describe "Detector validation lab", type: :request do
  let(:user) { create(:user) }
  let(:image) { fixture_file_upload("pothole.png", "image/png") }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "shows an image upload form" do
    get new_detector_validation_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Detector validation lab")
    expect(response.body).to include("Upload image")
  end

  it "validates an uploaded image and renders the detector result" do
    detector_result = {
      "detected" => true,
      "confidence" => 0.86,
      "threshold" => 0.25,
      "model_version" => "pot-yolo-int8-780aff5",
      "bounding_box" => {
        "left" => 0.15,
        "top" => 0.25,
        "right" => 0.45,
        "bottom" => 0.55
      },
      "detections" => []
    }

    allow(PotholeDetector::TfliteValidator).to receive(:new).and_return(instance_double(PotholeDetector::TfliteValidator, call: detector_result))

    post detector_validation_path, params: { detector_validation: { image: image } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Detected")
    expect(response.body).to include("86.0%")
    expect(response.body).to include("data:image/png;base64")
    expect(response.body).to include("validation-detection-box")
    expect(response.body).to include("--box-left: 15.0%")
  end

  it "renders detector validation errors" do
    allow(PotholeDetector::TfliteValidator).to receive(:new).and_raise(PotholeDetector::Unavailable, "install detector runtime")

    post detector_validation_path, params: { detector_validation: { image: image } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Detector validation lab")
    expect(response.body).to include("install detector runtime")
  end
end
