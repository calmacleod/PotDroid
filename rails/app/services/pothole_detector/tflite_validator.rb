require "json"
require "open3"
require "timeout"

module PotholeDetector
  class TfliteValidator
    MODEL_PATH = Rails.root.join("../android/app/src/main/assets/pot_yolo_int8.tflite").expand_path
    RUNNER_PATH = Rails.root.join("lib/pothole_detector/tflite_runner.py")
    LOCAL_PYTHON = Rails.root.join("tmp/detector-venv/bin/python")
    DEFAULT_PYTHON = ENV["POTDROID_DETECTOR_PYTHON"].presence || (LOCAL_PYTHON.exist? ? LOCAL_PYTHON.to_s : "python3")
    DEFAULT_THRESHOLD = 0.25
    TIMEOUT_SECONDS = 30

    def initialize(image:, threshold: DEFAULT_THRESHOLD)
      @image = image
      @threshold = threshold
    end

    def call
      stdout, stderr, status = Timeout.timeout(TIMEOUT_SECONDS) do
        Open3.capture3(
          { "PYTHONUNBUFFERED" => "1" },
          DEFAULT_PYTHON,
          RUNNER_PATH.to_s,
          "--model",
          MODEL_PATH.to_s,
          "--image",
          image_path,
          "--threshold",
          threshold.to_s
        )
      end

      raise_from_status(status, stderr)

      JSON.parse(stdout)
    rescue Timeout::Error
      raise InferenceError, "detector timed out after #{TIMEOUT_SECONDS} seconds"
    rescue JSON::ParserError => error
      raise InferenceError, "detector returned invalid JSON: #{error.message}"
    end

    private

    attr_reader :image, :threshold

    def image_path
      image.respond_to?(:tempfile) ? image.tempfile.path : image.path
    end

    def raise_from_status(status, stderr)
      return if status.success?

      message = stderr.to_s.presence || "detector failed with exit status #{status.exitstatus}"

      if status.exitstatus == 2
        raise Unavailable, message
      end

      raise InferenceError, message
    end
  end
end
