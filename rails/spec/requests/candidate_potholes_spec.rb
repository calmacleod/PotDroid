require "rails_helper"

RSpec.describe "Candidate pothole review", type: :request do
  let(:user) { create(:user) }
  let(:candidate) { create(:candidate_pothole, user: user) }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "lists the current user's candidate potholes" do
    candidate

    get candidate_potholes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Candidate potholes")
    expect(response.body).to include("fake-detector-v1").or include("91.0%")
  end

  it "shows the stored bounding box on the candidate image" do
    get candidate_pothole_path(candidate)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("detection-box")
    expect(response.body).to include("--box-left: 10.0%")
    expect(response.body).to include("--box-top: 20.0%")
    expect(response.body).to include("--box-width: 30.0%")
    expect(response.body).to include("--box-height: 30.0%")
  end

  it "runs detector validation for the candidate image and renders the result" do
    detector_result = {
      "detected" => true,
      "confidence" => 0.82,
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

    post validate_detector_candidate_pothole_path(candidate)
    expect(response).to redirect_to(candidate_pothole_path(candidate))

    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Detector validation")
    expect(response.body).to include("Detected")
    expect(response.body).to include("82.0%")
    expect(response.body).to include("validation-detection-box")
    expect(response.body).to include("--box-left: 15.0%")
  end

  it "renders detector validation errors on the review page" do
    allow(PotholeDetector::TfliteValidator).to receive(:new).and_raise(PotholeDetector::Unavailable, "install detector runtime")

    post validate_detector_candidate_pothole_path(candidate)
    expect(response).to redirect_to(candidate_pothole_path(candidate))

    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Detector validation")
    expect(response.body).to include("install detector runtime")
  end

  it "shows when an Android device is paired" do
    create(
      :pairing_session,
      user: user,
      claimed_at: 2.minutes.ago,
      device_name: "Pixel 9"
    )

    get candidate_potholes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Android paired")
    expect(response.body).to include("Pixel 9")
  end

  it "confirms a candidate" do
    patch confirm_candidate_pothole_path(candidate)

    expect(response).to redirect_to(candidate)
    expect(candidate.reload).to be_confirmed
    expect(candidate.reviewed_by).to eq(user)
  end

  it "rejects a candidate" do
    patch reject_candidate_pothole_path(candidate)

    expect(response).to redirect_to(candidate)
    expect(candidate.reload).to be_rejected
  end
end
