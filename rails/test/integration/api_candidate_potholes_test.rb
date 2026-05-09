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
              bounding_box: { left: 0.1, top: 0.2, right: 0.3, bottom: 0.4 }
            }
          },
          headers: @headers
      end
    end

    candidate = users(:one).candidate_potholes.order(:created_at).last
    assert_response :created
    assert candidate.image.attached?
    assert_equal "pending_review", json_response.dig("data", "attributes", "status")
    assert_equal "pending", json_response.dig("data", "attributes", "image_validation_status")
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
