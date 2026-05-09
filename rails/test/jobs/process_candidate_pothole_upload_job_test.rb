require "test_helper"

class ProcessCandidatePotholeUploadJobTest < ActiveJob::TestCase
  test "records an accepted async image validation" do
    candidate = candidate_potholes(:pending)
    result = { "accepted" => true, "threshold" => 0.35, "checks" => [ { "name" => "original", "passed" => true } ] }

    with_stubbed_method(PotholeDetector::ImageReliabilityValidator, :new, validator_factory(candidate, result)) do
      ProcessCandidatePotholeUploadJob.perform_now(candidate.id)
    end

    assert candidate.reload.image_validation_accepted?
    assert candidate.pending_review?
    assert_equal "original", candidate.image_validation_results.fetch("checks").first.fetch("name")
  end

  test "broadcasts a Turbo refresh after image validation completes" do
    candidate = candidate_potholes(:pending)
    result = { "accepted" => true, "threshold" => 0.35, "checks" => [ { "name" => "original", "passed" => true } ] }
    broadcasts = []

    with_stubbed_method(PotholeDetector::ImageReliabilityValidator, :new, validator_factory(candidate, result)) do
      with_stubbed_method(Turbo::StreamsChannel, :broadcast_stream_to, ->(*args, **kwargs) { broadcasts << [ args, kwargs ] }) do
        ProcessCandidatePotholeUploadJob.perform_now(candidate.id)
      end
    end

    assert_equal [ [ candidate ], { content: %(<turbo-stream action="refresh"></turbo-stream>) } ], broadcasts.last
  end

  test "returns an auto-rejected candidate to review when revalidation passes" do
    candidate = candidate_potholes(:pending)
    candidate.update!(
      status: :rejected,
      reviewed_by: nil,
      reviewed_at: 1.hour.ago,
      image_validation_status: :rejected
    )
    result = { "accepted" => true, "threshold" => 0.35, "checks" => [ { "name" => "original", "passed" => true } ] }

    with_stubbed_method(PotholeDetector::ImageReliabilityValidator, :new, validator_factory(candidate, result)) do
      ProcessCandidatePotholeUploadJob.perform_now(candidate.id)
    end

    assert candidate.reload.image_validation_accepted?
    assert candidate.pending_review?
    assert_nil candidate.reviewed_at
  end

  test "rejects the candidate when image validation does not pass every check" do
    candidate = candidate_potholes(:pending)
    result = { "accepted" => false, "threshold" => 0.35, "checks" => [ { "name" => "grayscale", "passed" => false } ] }

    with_stubbed_method(PotholeDetector::ImageReliabilityValidator, :new, validator_factory(candidate, result)) do
      ProcessCandidatePotholeUploadJob.perform_now(candidate.id)
    end

    assert candidate.reload.image_validation_rejected?
    assert candidate.rejected?
    assert candidate.reviewed_at.present?
  end

  test "marks validation failed when detector infrastructure errors" do
    candidate = candidate_potholes(:pending)
    error = PotholeDetector::Unavailable.new("install detector runtime")

    with_stubbed_method(PotholeDetector::ImageReliabilityValidator, :new, validator_factory(candidate, nil, error: error)) do
      ProcessCandidatePotholeUploadJob.perform_now(candidate.id)
    end

    assert candidate.reload.image_validation_failed?
    assert candidate.pending_review?
    assert_equal "install detector runtime", candidate.image_validation_error
  end

  test "broadcasts a Turbo refresh after image validation fails" do
    candidate = candidate_potholes(:pending)
    error = PotholeDetector::Unavailable.new("install detector runtime")
    broadcasts = []

    with_stubbed_method(PotholeDetector::ImageReliabilityValidator, :new, validator_factory(candidate, nil, error: error)) do
      with_stubbed_method(Turbo::StreamsChannel, :broadcast_stream_to, ->(*args, **kwargs) { broadcasts << [ args, kwargs ] }) do
        ProcessCandidatePotholeUploadJob.perform_now(candidate.id)
      end
    end

    assert_equal [ [ candidate ], { content: %(<turbo-stream action="refresh"></turbo-stream>) } ], broadcasts.last
  end

  private
    def validator_factory(expected_candidate, result, error: nil)
      lambda do |candidate_pothole:|
        assert_equal expected_candidate, candidate_pothole
        callable_result(result, error: error)
      end
    end
end
