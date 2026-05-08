require "fileutils"
require "mini_magick"
require "tempfile"

module PotholeDetector
  class ImageReliabilityValidator
    Transformation = Struct.new(:name, :operation, keyword_init: true)

    DEFAULT_THRESHOLD = 0.35
    DEFAULT_TRANSFORMATIONS = [
      Transformation.new(name: "original"),
      Transformation.new(
        name: "resized_960",
        operation: ->(source_path, output_path) do
          transform(source_path, output_path) { |image| image.resize "960x960>" }
        end
      ),
      Transformation.new(
        name: "grayscale",
        operation: ->(source_path, output_path) do
          transform(source_path, output_path) { |image| image.colorspace "Gray" }
        end
      ),
      Transformation.new(
        name: "auto_level",
        operation: ->(source_path, output_path) do
          transform(source_path, output_path, &:auto_level)
        end
      ),
      Transformation.new(
        name: "compressed",
        operation: ->(source_path, output_path) do
          transform(source_path, output_path) { |image| image.quality "70" }
        end
      )
    ].freeze

    def self.transform(source_path, output_path)
      image = MiniMagick::Image.open(source_path)
      image.auto_orient
      yield image
      image.write(output_path)
    ensure
      image&.destroy!
    end

    def initialize(candidate_pothole:, detector: TfliteValidator, threshold: DEFAULT_THRESHOLD, transformations: DEFAULT_TRANSFORMATIONS)
      @candidate_pothole = candidate_pothole
      @detector = detector
      @threshold = threshold
      @transformations = transformations
    end

    def call
      raise InferenceError, "candidate has no image attached" unless candidate_pothole.image.attached?

      with_downloaded_image do |original|
        checks = transformations.map { |transformation| run_check(original, transformation) }

        {
          "accepted" => checks.all? { |check| check.fetch("passed") },
          "threshold" => threshold,
          "checks" => checks
        }
      end
    rescue MiniMagick::Error => error
      raise InferenceError, "image transformation failed: #{error.message}"
    end

    private

    attr_reader :candidate_pothole, :detector, :threshold, :transformations

    def with_downloaded_image
      Tempfile.create([ "candidate-pothole-#{candidate_pothole.id}", candidate_pothole.image.filename.extension_with_delimiter ]) do |file|
        file.binmode
        file.write(candidate_pothole.image.download)
        file.flush

        yield file
      end
    end

    def run_check(original, transformation)
      with_transformed_image(original, transformation) do |image|
        result = detector.new(image: image, threshold: threshold).call
        normalized_result = normalize_result(result)

        {
          "name" => transformation.name,
          "passed" => detected_reliably?(normalized_result),
          "detected" => normalized_result["detected"] == true,
          "confidence" => normalized_result["confidence"],
          "bounding_box" => normalized_result["bounding_box"],
          "result" => normalized_result
        }
      end
    end

    def with_transformed_image(original, transformation)
      return yield original if transformation.operation.blank?

      Tempfile.create([ "#{transformation.name}-", File.extname(original.path) ]) do |file|
        file.binmode
        transformation.operation.call(original.path, file.path)
        file.flush

        yield file
      end
    end

    def detected_reliably?(result)
      result["detected"] == true && result["confidence"].to_f >= threshold
    end

    def normalize_result(result)
      result.deep_stringify_keys
    end
  end
end
