ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "json"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      CandidatePothole.find_each { |candidate| attach_pothole_image(candidate) } if defined?(CandidatePothole)
    end

    def pothole_image_upload
      Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/pothole.png").to_s, "image/png")
    end

    def build_candidate_pothole(attributes = {})
      candidate = CandidatePothole.new(candidate_pothole_attributes(attributes))
      attach_pothole_image(candidate)
      candidate
    end

    def create_candidate_pothole!(attributes = {})
      build_candidate_pothole(attributes).tap(&:save!)
    end

    def attach_pothole_image(candidate)
      return candidate if candidate.image.attached?

      candidate.image.attach(
        io: File.open(file_fixture("pothole.png")),
        filename: "pothole.png",
        content_type: "image/png"
      )
      candidate
    end

    def detector_result(detected: true, confidence: 0.82, bounding_box: nil)
      {
        "detected" => detected,
        "confidence" => confidence,
        "threshold" => 0.25,
        "model_version" => "pot-yolo-int8-780aff5",
        "bounding_box" => bounding_box || (detected ? { "left" => 0.1, "top" => 0.2, "right" => 0.4, "bottom" => 0.5 } : nil),
        "detections" => []
      }
    end

    def callable_result(result = nil, error: nil)
      Object.new.tap do |callable|
        callable.define_singleton_method(:call) do
          raise error if error

          result
        end
      end
    end

    def json_response
      ::JSON.parse(response.body)
    end

    def with_stubbed_method(object, method_name, replacement)
      singleton = object.singleton_class
      original = object.method(method_name)

      singleton.define_method(method_name) do |*args, **kwargs, &block|
        replacement.call(*args, **kwargs, &block)
      end

      yield
    ensure
      singleton.define_method(method_name) do |*args, **kwargs, &block|
        original.call(*args, **kwargs, &block)
      end
    end

    private
      def candidate_pothole_attributes(attributes)
        {
          user: users(:one),
          status: :pending_review,
          latitude: "45.4215",
          longitude: "-75.6972",
          heading: "180.0",
          speed: "12.5",
          detector_confidence: "0.91",
          detector_model_version: "fake-detector-v1",
          bounding_box: { "left" => 0.1, "top" => 0.2, "right" => 0.4, "bottom" => 0.5 },
          accelerometer_data: {
            "sensor_type" => "linear_acceleration",
            "sample_rate_hz" => 50.0,
            "peak_magnitude" => 6.4,
            "bump_threshold" => 5.0,
            "bump_detected" => true,
            "samples" => [
              { "elapsed_millis" => 1_000, "x" => 0.1, "y" => 0.2, "z" => 6.4, "magnitude" => 6.4 }
            ]
          },
          captured_at: Time.zone.parse("2026-05-08 08:45:29")
        }.merge(attributes)
      end
  end
end
