require "test_helper"

class PotholeDetector::ImageReliabilityValidatorTest < ActiveSupport::TestCase
  setup do
    @candidate = candidate_potholes(:pending)
    @transformations = [
      PotholeDetector::ImageReliabilityValidator::Transformation.new(name: "original"),
      PotholeDetector::ImageReliabilityValidator::Transformation.new(
        name: "copy",
        operation: ->(source_path, output_path) { FileUtils.cp(source_path, output_path) }
      )
    ]
  end

  test "accepts the image only when every transformed detector check passes" do
    detector = fake_detector([ detector_result(detected: true, confidence: 0.82), detector_result(detected: true, confidence: 0.76) ])

    result = PotholeDetector::ImageReliabilityValidator.new(
      candidate_pothole: @candidate,
      detector: detector,
      threshold: 0.35,
      transformations: @transformations
    ).call

    assert_equal true, result["accepted"]
    assert_equal %w[original copy], result["checks"].map { |check| check["name"] }
    assert result["checks"].all? { |check| check["passed"] == true }
  end

  test "rejects the image when any transformed detector check misses" do
    detector = fake_detector([ detector_result(detected: true, confidence: 0.82), detector_result(detected: false, confidence: nil) ])

    result = PotholeDetector::ImageReliabilityValidator.new(
      candidate_pothole: @candidate,
      detector: detector,
      threshold: 0.35,
      transformations: @transformations
    ).call

    assert_equal false, result["accepted"]
    assert_equal "copy", result["checks"].last["name"]
    assert_equal false, result["checks"].last["passed"]
    assert_equal false, result["checks"].last["detected"]
  end

  private
    def fake_detector(results)
      Class.new.tap do |detector|
        detector.define_singleton_method(:new) do |image:, threshold:|
          Object.new.tap do |callable|
            callable.define_singleton_method(:call) { results.shift }
          end
        end
      end
    end
end
