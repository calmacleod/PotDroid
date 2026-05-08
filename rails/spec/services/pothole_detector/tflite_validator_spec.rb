require "rails_helper"

RSpec.describe PotholeDetector::TfliteValidator do
  let(:image) { fixture_file_upload("pothole.png", "image/png") }
  let(:result) do
    {
      detected: true,
      confidence: 0.8,
      threshold: 0.25,
      model_version: "pot-yolo-int8-780aff5",
      bounding_box: { left: 0.1, top: 0.2, right: 0.4, bottom: 0.5 },
      detections: []
    }
  end

  it "runs the Python detector against the uploaded image" do
    stdout = JSON.generate(result)
    status = instance_double(Process::Status, success?: true)

    expect(Open3).to receive(:capture3).with(
      hash_including("PYTHONUNBUFFERED" => "1"),
      described_class::DEFAULT_PYTHON,
      described_class::RUNNER_PATH.to_s,
      "--model",
      described_class::MODEL_PATH.to_s,
      "--image",
      image.tempfile.path,
      "--threshold",
      "0.25"
    ).and_return([ stdout, "", status ])

    expect(described_class.new(image: image).call).to eq(JSON.parse(stdout))
  end

  it "raises unavailable when the Python runner reports a missing dependency" do
    status = instance_double(Process::Status, success?: false, exitstatus: 2)

    expect(Open3).to receive(:capture3).and_return([ "", "missing dependency", status ])

    expect do
      described_class.new(image: image).call
    end.to raise_error(PotholeDetector::Unavailable, "missing dependency")
  end
end
