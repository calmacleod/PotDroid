require "test_helper"

class ApiDetectorValidationsTest < ActionDispatch::IntegrationTest
  setup do
    _api_token, @raw_token = ApiToken.issue!(user: users(:one), name: "Detector validation")
    @headers = { "Authorization" => "Bearer #{@raw_token}" }
  end

  test "returns the local detector result for an uploaded image" do
    result = detector_result
    calls = []
    validator_factory = lambda do |image:, threshold:|
      calls << { image: image, threshold: threshold }
      callable_result(result)
    end

    with_stubbed_method(PotholeDetector::TfliteValidator, :new, validator_factory) do
      post api_v1_detector_validation_path,
        params: { image: pothole_image_upload, threshold: "0.65" },
        headers: @headers
    end

    assert_kind_of ActionDispatch::Http::UploadedFile, calls.first.fetch(:image)
    assert_equal 0.65, calls.first.fetch(:threshold)
    assert_response :ok
    assert_equal result, json_response
  end

  test "rejects requests without an image" do
    post api_v1_detector_validation_path, headers: @headers

    assert_response :bad_request
    assert_equal "bad_request", json_response["code"]
  end

  test "returns unavailable when the local detector runtime is missing" do
    with_stubbed_method(PotholeDetector::TfliteValidator, :new, ->(**) { raise PotholeDetector::Unavailable, "install ai-edge-litert" }) do
      post api_v1_detector_validation_path,
        params: { image: pothole_image_upload },
        headers: @headers
    end

    assert_response :service_unavailable
    assert_equal({ "code" => "detector_unavailable", "error" => "install ai-edge-litert" }, json_response)
  end

  test "returns unprocessable when local inference fails" do
    with_stubbed_method(PotholeDetector::TfliteValidator, :new, ->(**) { raise PotholeDetector::InferenceError, "bad image" }) do
      post api_v1_detector_validation_path,
        params: { image: pothole_image_upload },
        headers: @headers
    end

    assert_response :unprocessable_content
    assert_equal({ "code" => "detector_inference_failed", "error" => "bad image" }, json_response)
  end
end
