require "rails_helper"

RSpec.describe ProcessCandidatePotholeUploadJob, type: :job do
  it "records an accepted async image validation" do
    candidate = create(:candidate_pothole)
    validator = instance_double(
      PotholeDetector::ImageReliabilityValidator,
      call: { "accepted" => true, "threshold" => 0.35, "checks" => [ { "name" => "original", "passed" => true } ] }
    )

    allow(PotholeDetector::ImageReliabilityValidator).to receive(:new).with(candidate_pothole: candidate).and_return(validator)

    described_class.perform_now(candidate.id)

    expect(candidate.reload).to be_image_validation_accepted
    expect(candidate).to be_pending_review
    expect(candidate.image_validation_results.fetch("checks").first.fetch("name")).to eq("original")
  end

  it "broadcasts a Turbo refresh after image validation completes" do
    candidate = create(:candidate_pothole)
    validator = instance_double(
      PotholeDetector::ImageReliabilityValidator,
      call: { "accepted" => true, "threshold" => 0.35, "checks" => [ { "name" => "original", "passed" => true } ] }
    )

    allow(PotholeDetector::ImageReliabilityValidator).to receive(:new).with(candidate_pothole: candidate).and_return(validator)
    expect(Turbo::StreamsChannel).to receive(:broadcast_stream_to).with(
      candidate,
      content: %(<turbo-stream action="refresh"></turbo-stream>)
    )

    described_class.perform_now(candidate.id)
  end

  it "returns an auto-rejected candidate to review when revalidation passes" do
    candidate = create(
      :candidate_pothole,
      status: :rejected,
      reviewed_by: nil,
      reviewed_at: 1.hour.ago,
      image_validation_status: :rejected
    )
    validator = instance_double(
      PotholeDetector::ImageReliabilityValidator,
      call: { "accepted" => true, "threshold" => 0.35, "checks" => [ { "name" => "original", "passed" => true } ] }
    )

    allow(PotholeDetector::ImageReliabilityValidator).to receive(:new).with(candidate_pothole: candidate).and_return(validator)

    described_class.perform_now(candidate.id)

    expect(candidate.reload).to be_image_validation_accepted
    expect(candidate).to be_pending_review
    expect(candidate.reviewed_at).to be_nil
  end

  it "rejects the candidate when image validation does not pass every check" do
    candidate = create(:candidate_pothole)
    validator = instance_double(
      PotholeDetector::ImageReliabilityValidator,
      call: { "accepted" => false, "threshold" => 0.35, "checks" => [ { "name" => "grayscale", "passed" => false } ] }
    )

    allow(PotholeDetector::ImageReliabilityValidator).to receive(:new).with(candidate_pothole: candidate).and_return(validator)

    described_class.perform_now(candidate.id)

    expect(candidate.reload).to be_image_validation_rejected
    expect(candidate).to be_rejected
    expect(candidate.reviewed_at).to be_present
  end

  it "marks validation failed when detector infrastructure errors" do
    candidate = create(:candidate_pothole)
    validator = instance_double(PotholeDetector::ImageReliabilityValidator)

    allow(PotholeDetector::ImageReliabilityValidator).to receive(:new).with(candidate_pothole: candidate).and_return(validator)
    allow(validator).to receive(:call).and_raise(PotholeDetector::Unavailable, "install detector runtime")

    described_class.perform_now(candidate.id)

    expect(candidate.reload).to be_image_validation_failed
    expect(candidate).to be_pending_review
    expect(candidate.image_validation_error).to eq("install detector runtime")
  end

  it "broadcasts a Turbo refresh after image validation fails" do
    candidate = create(:candidate_pothole)
    validator = instance_double(PotholeDetector::ImageReliabilityValidator)

    allow(PotholeDetector::ImageReliabilityValidator).to receive(:new).with(candidate_pothole: candidate).and_return(validator)
    allow(validator).to receive(:call).and_raise(PotholeDetector::Unavailable, "install detector runtime")
    expect(Turbo::StreamsChannel).to receive(:broadcast_stream_to).with(
      candidate,
      content: %(<turbo-stream action="refresh"></turbo-stream>)
    )

    described_class.perform_now(candidate.id)
  end
end
