require "test_helper"

class DetectorValidationsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "shows an image upload form" do
    get new_detector_validation_path

    assert_response :ok
    assert_includes response.body, "Detector validation lab"
    assert_includes response.body, "Upload image"
  end

  test "validates an uploaded image and renders the detector result" do
    result = detector_result(confidence: 0.86, bounding_box: { "left" => 0.15, "top" => 0.25, "right" => 0.45, "bottom" => 0.55 })

    with_stubbed_method(PotholeDetector::TfliteValidator, :new, ->(image:, threshold:) { callable_result(result) }) do
      post detector_validation_path, params: { detector_validation: { image: pothole_image_upload } }
    end

    assert_response :ok
    assert_includes response.body, "Detected"
    assert_includes response.body, "86.0%"
    assert_includes response.body, "data:image/png;base64"
    assert_includes response.body, "validation-detection-box"
    assert_includes response.body, "--box-left: 15.0%"
  end

  test "renders detector validation errors" do
    with_stubbed_method(PotholeDetector::TfliteValidator, :new, ->(image:, threshold:) { raise PotholeDetector::Unavailable, "install detector runtime" }) do
      post detector_validation_path, params: { detector_validation: { image: pothole_image_upload } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Detector validation lab"
    assert_includes response.body, "install detector runtime"
  end
end
