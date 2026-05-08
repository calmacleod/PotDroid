require "net/http"

module CitySubmissions
  module Ottawa
    class Open311Connector < CitySubmissions::Connector
      CONNECTOR_NAME = "ottawa_open311"
      DEFAULT_ENDPOINT = "https://city-of-ottawa-prod.apigee.net/open311/v2"
      DEFAULT_JURISDICTION = "ottawa.ca"
      DEFAULT_SERVICE_CODE = "Pothole on the Road"

      def submit(candidate_pothole)
        return manual_packet(candidate_pothole) if api_key.blank?

        uri = URI("#{endpoint}/requests.json")
        response = Net::HTTP.post_form(uri, request_params(candidate_pothole))
        payload = JSON.parse(response.body)

        if response.is_a?(Net::HTTPSuccess)
          request = Array(payload).first || payload
          CitySubmissions::Result.new(
            status: :submitted,
            external_request_id: request["service_request_id"] || request["token"],
            external_status: request["status"] || "submitted",
            payload: payload,
            message: request["service_notice"]
          )
        else
          CitySubmissions::Result.new(
            status: :failed,
            external_request_id: nil,
            external_status: response.code,
            payload: payload,
            message: "Ottawa Open311 rejected the submission."
          )
        end
      rescue JSON::ParserError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout => error
        CitySubmissions::Result.new(
          status: :failed,
          external_request_id: nil,
          external_status: nil,
          payload: { error: error.class.name },
          message: error.message
        )
      end

      def status(city_submission)
        return unsupported_status(city_submission) if api_key.blank? || city_submission.external_request_id.blank?

        uri = URI("#{endpoint}/requests/#{city_submission.external_request_id}.json")
        uri.query = URI.encode_www_form(jurisdiction_id: jurisdiction_id)
        response = Net::HTTP.get_response(uri)
        payload = JSON.parse(response.body)
        request = Array(payload).first || payload

        CitySubmissions::Result.new(
          status: request["status"] == "closed" ? :closed : :submitted,
          external_request_id: city_submission.external_request_id,
          external_status: request["status"],
          payload: payload,
          message: request["description"]
        )
      rescue JSON::ParserError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout => error
        CitySubmissions::Result.new(
          status: :failed,
          external_request_id: city_submission.external_request_id,
          external_status: nil,
          payload: { error: error.class.name },
          message: error.message
        )
      end

      private

      def request_params(candidate_pothole)
        {
          api_key: api_key,
          jurisdiction_id: jurisdiction_id,
          service_code: service_code,
          lat: candidate_pothole.latitude.to_s,
          long: candidate_pothole.longitude.to_s,
          description: description(candidate_pothole)
        }
      end

      def description(candidate_pothole)
        "Possible pothole detected by PotDroid at #{candidate_pothole.captured_at.iso8601}. " \
          "Model #{candidate_pothole.detector_model_version || "unknown"} confidence " \
          "#{candidate_pothole.detector_confidence}."
      end

      def manual_packet(candidate_pothole)
        CitySubmissions::Result.new(
          status: :manual_required,
          external_request_id: nil,
          external_status: "api_key_missing",
          payload: {
            service: "Pothole on the roadway",
            latitude: candidate_pothole.latitude.to_s,
            longitude: candidate_pothole.longitude.to_s,
            description: description(candidate_pothole),
            photo_limit_mb: 6
          },
          message: "Set OTTAWA_OPEN311_API_KEY to submit automatically."
        )
      end

      def unsupported_status(city_submission)
        CitySubmissions::Result.new(
          status: city_submission.status.to_sym,
          external_request_id: city_submission.external_request_id,
          external_status: city_submission.external_status,
          payload: {},
          message: "Status polling requires an Ottawa request id and API key."
        )
      end

      def endpoint
        ENV.fetch("OTTAWA_OPEN311_ENDPOINT", DEFAULT_ENDPOINT)
      end

      def jurisdiction_id
        ENV.fetch("OTTAWA_OPEN311_JURISDICTION_ID", DEFAULT_JURISDICTION)
      end

      def service_code
        ENV.fetch("OTTAWA_OPEN311_POTHOLE_SERVICE_CODE", DEFAULT_SERVICE_CODE)
      end

      def api_key
        ENV["OTTAWA_OPEN311_API_KEY"]
      end
    end
  end
end
