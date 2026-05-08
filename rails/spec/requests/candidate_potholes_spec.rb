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
    expect(response.body).to include("turbo-cable-stream-source")
    expect(response.body).to include("detection-box")
    expect(response.body).to include("--box-left: 10.0%")
    expect(response.body).to include("--box-top: 20.0%")
    expect(response.body).to include("--box-width: 30.0%")
    expect(response.body).to include("--box-height: 30.0%")
  end

  it "renders a Mapbox candidate map with filterable candidate data" do
    candidate

    original_token = ENV["MAPBOX_ACCESS_TOKEN"]
    begin
      ENV["MAPBOX_ACCESS_TOKEN"] = "pk.test"
      get map_candidate_potholes_path(status: "pending_review")
    ensure
      ENV["MAPBOX_ACCESS_TOKEN"] = original_token
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pothole map")
    expect(response.body).to include("https://api.mapbox.com/mapbox-gl-js")
    expect(response.body).to include("data-mapbox-token=\"pk.test\"")
    expect(response.body).to include("\"id\":#{candidate.id}")
    expect(response.body).to include("\"status\":\"pending_review\"")
    expect(response.body).to include("satellite-streets-v12")
    expect(response.body).to include("cluster: true")
    expect(response.body).to include("candidate-map-inspector")
    expect(response.body).to include("openCandidateFromCluster")
    expect(response.body).to include("map-inspector-list-item")
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

  it "does not store the full detector detections array in the flash cookie" do
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
      "detections" => Array.new(150) do |index|
        {
          "confidence" => 0.5 + (index / 1000.0),
          "bounding_box" => {
            "left" => 0.1,
            "top" => 0.2,
            "right" => 0.3,
            "bottom" => 0.4
          }
        }
      end
    }

    allow(PotholeDetector::TfliteValidator).to receive(:new).and_return(instance_double(PotholeDetector::TfliteValidator, call: detector_result))

    post validate_detector_candidate_pothole_path(candidate)

    flash_payload = request.flash[:detector_validation_result]
    expect(flash_payload).to include("detected", "confidence", "threshold", "model_version", "bounding_box")
    expect(flash_payload).not_to have_key("detections")
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

  it "queues forced async image revalidation from the review page" do
    candidate.update!(
      image_validation_status: :failed,
      image_validation_results: { "checks" => [ { "name" => "original", "passed" => false } ] },
      image_validation_error: "detector failed",
      image_validated_at: 1.hour.ago
    )
    allow(ProcessCandidatePotholeUploadJob).to receive(:perform_later)

    post revalidate_image_candidate_pothole_path(candidate)

    expect(response).to redirect_to(candidate_pothole_path(candidate))
    expect(ProcessCandidatePotholeUploadJob).to have_received(:perform_later).with(candidate.id)
    expect(candidate.reload).to be_image_validation_pending
    expect(candidate.image_validation_results).to be_nil
    expect(candidate.image_validation_error).to be_nil
    expect(candidate.image_validated_at).to be_nil
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
