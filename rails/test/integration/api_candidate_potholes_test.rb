require "test_helper"

class ApiCandidatePotholesTest < ActionDispatch::IntegrationTest
  setup do
    _api_token, @raw_token = ApiToken.issue!(user: users(:one), name: "Android")
    @headers = { "Authorization" => "Bearer #{@raw_token}" }
  end

  test "creates an authenticated candidate pothole upload" do
    assert_enqueued_with(job: ProcessCandidatePotholeUploadJob) do
      assert_difference -> { users(:one).candidate_potholes.count }, 1 do
        post api_v1_candidate_potholes_path,
          params: {
            candidate_pothole: {
              image: pothole_image_upload,
              latitude: "45.4215",
              longitude: "-75.6972",
              detector_confidence: "0.88",
              detector_model_version: "fake-detector-v1",
              captured_at: "2026-05-08T12:00:00Z",
              accelerometer_data: JSON.generate(
                sensor_type: "linear_acceleration",
                sensor_name: "Pixel linear acceleration",
                includes_gravity: false,
                sample_rate_hz: 48.5,
                window_start_elapsed_millis: 1_000,
                window_end_elapsed_millis: 1_900,
                peak_magnitude: 7.2,
                bump_threshold: 5.0,
                bump_detected: true,
                samples: [
                  { elapsed_millis: 1_000, x: 0.1, y: 0.2, z: 1.1, magnitude: 1.12 },
                  { elapsed_millis: 1_900, x: 0.4, y: 0.3, z: 7.2, magnitude: 7.22 }
                ]
              ),
              bounding_box: { left: 0.1, top: 0.2, right: 0.3, bottom: 0.4 }
            }
          },
          headers: @headers
      end
    end

    candidate = users(:one).candidate_potholes.order(:created_at).last
    assert_response :created
    assert candidate.image.attached?
    assert_equal "linear_acceleration", candidate.accelerometer_data.fetch("sensor_type")
    assert_equal 7.2, candidate.accelerometer_data.fetch("peak_magnitude")
    assert_equal true, candidate.accelerometer_data.fetch("bump_detected")
    assert_equal "linear_acceleration", json_response.dig("data", "attributes", "accelerometer_data", "sensor_type")
    assert_equal "pending_review", json_response.dig("data", "attributes", "status")
    assert_equal "pending", json_response.dig("data", "attributes", "image_validation_status")
  end

  test "rejects malformed accelerometer data" do
    post api_v1_candidate_potholes_path,
      params: {
        candidate_pothole: {
          image: pothole_image_upload,
          latitude: "45.4215",
          longitude: "-75.6972",
          detector_confidence: "0.88",
          detector_model_version: "fake-detector-v1",
          captured_at: "2026-05-08T12:00:00Z",
          accelerometer_data: "{",
          bounding_box: { left: 0.1, top: 0.2, right: 0.3, bottom: 0.4 }
        }
      },
      headers: @headers

    assert_response :bad_request
    assert_equal "bad_request", json_response.fetch("code")
  end

  test "rejects missing tokens" do
    post api_v1_candidate_potholes_path, params: { candidate_pothole: {} }

    assert_response :unauthorized
  end

  test "returns only the current user's candidate" do
    candidate = candidate_potholes(:pending)

    get api_v1_candidate_pothole_path(candidate), headers: @headers

    assert_response :ok
    assert_equal candidate.id, json_response.dig("data", "id")
  end
end
