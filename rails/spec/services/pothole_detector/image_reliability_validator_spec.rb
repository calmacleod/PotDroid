require "rails_helper"

RSpec.describe PotholeDetector::ImageReliabilityValidator do
  let(:candidate) { create(:candidate_pothole) }
  let(:detector) { class_double(PotholeDetector::TfliteValidator) }
  let(:transformations) do
    [
      described_class::Transformation.new(name: "original"),
      described_class::Transformation.new(
        name: "copy",
        operation: ->(source_path, output_path) { FileUtils.cp(source_path, output_path) }
      )
    ]
  end

  it "accepts the image only when every transformed detector check passes" do
    allow(detector).to receive(:new).and_return(
      instance_double(PotholeDetector::TfliteValidator, call: detector_result(true, 0.82)),
      instance_double(PotholeDetector::TfliteValidator, call: detector_result(true, 0.76))
    )

    result = described_class.new(
      candidate_pothole: candidate,
      detector: detector,
      threshold: 0.35,
      transformations: transformations
    ).call

    expect(result["accepted"]).to be(true)
    expect(result["checks"].map { |check| check["name"] }).to eq(%w[original copy])
    expect(result["checks"]).to all(include("passed" => true))
  end

  it "rejects the image when any transformed detector check misses" do
    allow(detector).to receive(:new).and_return(
      instance_double(PotholeDetector::TfliteValidator, call: detector_result(true, 0.82)),
      instance_double(PotholeDetector::TfliteValidator, call: detector_result(false, nil))
    )

    result = described_class.new(
      candidate_pothole: candidate,
      detector: detector,
      threshold: 0.35,
      transformations: transformations
    ).call

    expect(result["accepted"]).to be(false)
    expect(result["checks"].last).to include("name" => "copy", "passed" => false, "detected" => false)
  end

  def detector_result(detected, confidence)
    {
      "detected" => detected,
      "confidence" => confidence,
      "threshold" => 0.35,
      "model_version" => "pot-yolo-int8-780aff5",
      "bounding_box" => detected ? { "left" => 0.1, "top" => 0.2, "right" => 0.4, "bottom" => 0.5 } : nil,
      "detections" => []
    }
  end
end
