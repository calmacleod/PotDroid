require "test_helper"

class PotholeDetector::TfliteValidatorTest < ActiveSupport::TestCase
  FakeStatus = Struct.new(:success_value, :exitstatus) do
    def success?
      success_value
    end
  end

  test "runs the Python detector against the uploaded image" do
    image = pothole_image_upload
    result = {
      detected: true,
      confidence: 0.8,
      threshold: 0.25,
      model_version: "pot-yolo-int8-780aff5",
      bounding_box: { left: 0.1, top: 0.2, right: 0.4, bottom: 0.5 },
      detections: []
    }
    stdout = JSON.generate(result)
    status = FakeStatus.new(true, 0)
    captured_args = nil

    with_stubbed_method(Open3, :capture3, ->(*args) { captured_args = args; [ stdout, "", status ] }) do
      assert_equal JSON.parse(stdout), PotholeDetector::TfliteValidator.new(image: image).call
    end

    assert_equal({ "PYTHONUNBUFFERED" => "1" }, captured_args[0])
    assert_equal PotholeDetector::TfliteValidator::DEFAULT_PYTHON, captured_args[1]
    assert_equal PotholeDetector::TfliteValidator::RUNNER_PATH.to_s, captured_args[2]
    assert_equal "--model", captured_args[3]
    assert_equal PotholeDetector::TfliteValidator::MODEL_PATH.to_s, captured_args[4]
    assert_equal "--image", captured_args[5]
    assert_equal image.tempfile.path, captured_args[6]
    assert_equal "--threshold", captured_args[7]
    assert_equal "0.25", captured_args[8]
  end

  test "raises unavailable when the Python runner reports a missing dependency" do
    status = FakeStatus.new(false, 2)

    with_stubbed_method(Open3, :capture3, ->(*) { [ "", "missing dependency", status ] }) do
      error = assert_raises(PotholeDetector::Unavailable) do
        PotholeDetector::TfliteValidator.new(image: pothole_image_upload).call
      end
      assert_equal "missing dependency", error.message
    end
  end
end
