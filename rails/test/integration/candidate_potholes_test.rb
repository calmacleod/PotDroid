require "test_helper"

class CandidatePotholesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @candidate = candidate_potholes(:pending)
    sign_in_as(@user)
  end

  test "lists the current user's candidate potholes" do
    get candidate_potholes_path

    assert_response :ok
    assert_includes response.body, "Candidate potholes"
    assert_match(/fake-detector-v1|91.0%/, response.body)
  end

  test "shows the stored bounding box on the candidate image" do
    get candidate_pothole_path(@candidate)

    assert_response :ok
    assert_includes response.body, "turbo-cable-stream-source"
    assert_includes response.body, "detection-box"
    assert_includes response.body, "--box-left: 10.0%"
    assert_includes response.body, "--box-top: 20.0%"
    assert_includes response.body, "--box-width: 30.0%"
    assert_includes response.body, "--box-height: 30.0%"
  end

  test "renders a Mapbox candidate map with filterable candidate data" do
    with_env("MAPBOX_ACCESS_TOKEN" => "pk.test") do
      get map_candidate_potholes_path(status: "pending_review")
    end

    assert_response :ok
    assert_includes response.body, "Pothole map"
    assert_includes response.body, "https://api.mapbox.com/mapbox-gl-js"
    assert_includes response.body, 'data-mapbox-token="pk.test"'
    assert_includes response.body, %(&quot;id&quot;:#{@candidate.id})
    assert_includes response.body, %(&quot;status&quot;:&quot;pending_review&quot;)
    assert_includes response.body, "satellite-streets-v12"
    assert_includes response.body, "cluster: true"
    assert_includes response.body, "candidate-map-inspector"
    assert_includes response.body, "openCandidateFromCluster"
    assert_includes response.body, "map-inspector-list-item"
  end

  test "runs detector validation for the candidate image and renders the result" do
    result = detector_result(confidence: 0.82, bounding_box: { "left" => 0.15, "top" => 0.25, "right" => 0.45, "bottom" => 0.55 })

    with_stubbed_method(PotholeDetector::TfliteValidator, :new, ->(image:, threshold: PotholeDetector::TfliteValidator::DEFAULT_THRESHOLD) { callable_result(result) }) do
      post validate_detector_candidate_pothole_path(@candidate)
    end
    assert_redirected_to candidate_pothole_path(@candidate)

    follow_redirect!
    assert_response :ok
    assert_includes response.body, "Detector validation"
    assert_includes response.body, "Detected"
    assert_includes response.body, "82.0%"
    assert_includes response.body, "validation-detection-box"
    assert_includes response.body, "--box-left: 15.0%"
  end

  test "does not store the full detector detections array in the flash cookie" do
    result = detector_result(confidence: 0.82, bounding_box: { "left" => 0.15, "top" => 0.25, "right" => 0.45, "bottom" => 0.55 })
    result["detections"] = Array.new(150) do |index|
      {
        "confidence" => 0.5 + (index / 1000.0),
        "bounding_box" => { "left" => 0.1, "top" => 0.2, "right" => 0.3, "bottom" => 0.4 }
      }
    end

    with_stubbed_method(PotholeDetector::TfliteValidator, :new, ->(image:, threshold: PotholeDetector::TfliteValidator::DEFAULT_THRESHOLD) { callable_result(result) }) do
      post validate_detector_candidate_pothole_path(@candidate)
    end

    flash_payload = flash[:detector_validation_result]
    assert_includes flash_payload.keys, "detected"
    assert_includes flash_payload.keys, "confidence"
    assert_includes flash_payload.keys, "threshold"
    assert_includes flash_payload.keys, "model_version"
    assert_includes flash_payload.keys, "bounding_box"
    assert_not_includes flash_payload.keys, "detections"
  end

  test "renders detector validation errors on the review page" do
    with_stubbed_method(PotholeDetector::TfliteValidator, :new, ->(image:, threshold: PotholeDetector::TfliteValidator::DEFAULT_THRESHOLD) { raise PotholeDetector::Unavailable, "install detector runtime" }) do
      post validate_detector_candidate_pothole_path(@candidate)
    end
    assert_redirected_to candidate_pothole_path(@candidate)

    follow_redirect!
    assert_response :ok
    assert_includes response.body, "Detector validation"
    assert_includes response.body, "install detector runtime"
  end

  test "queues forced async image revalidation from the review page" do
    @candidate.update!(
      image_validation_status: :failed,
      image_validation_results: { "checks" => [ { "name" => "original", "passed" => false } ] },
      image_validation_error: "detector failed",
      image_validated_at: 1.hour.ago
    )

    assert_enqueued_with(job: ProcessCandidatePotholeUploadJob, args: [ @candidate.id ]) do
      post revalidate_image_candidate_pothole_path(@candidate)
    end

    assert_redirected_to candidate_pothole_path(@candidate)
    assert @candidate.reload.image_validation_pending?
    assert_nil @candidate.image_validation_results
    assert_nil @candidate.image_validation_error
    assert_nil @candidate.image_validated_at
  end

  test "shows when an Android device is paired" do
    get candidate_potholes_path

    assert_response :ok
    assert_includes response.body, "Android paired"
    assert_includes response.body, "Pixel 9"
  end

  test "confirms a candidate" do
    patch confirm_candidate_pothole_path(@candidate)

    assert_redirected_to @candidate
    assert @candidate.reload.confirmed?
    assert_equal @user, @candidate.reviewed_by
  end

  test "rejects a candidate" do
    patch reject_candidate_pothole_path(@candidate)

    assert_redirected_to @candidate
    assert @candidate.reload.rejected?
  end

  private
    def with_env(values)
      originals = values.keys.to_h { |key| [ key, ENV[key] ] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      originals.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end
end
