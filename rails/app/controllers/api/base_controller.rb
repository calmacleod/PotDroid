module Api
  class BaseController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate_api_token!

    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
    rescue_from ActionController::ParameterMissing, with: :bad_request

    private

    def authenticate_api_token!
      authenticate_or_request_with_http_token do |token, _options|
        if api_token = ApiToken.authenticate(token)
          Current.user = api_token.user
        end
      end
    end

    def not_found(exception)
      render json: { error: exception.message, code: "not_found" }, status: :not_found
    end

    def unprocessable_entity(exception)
      render json: { errors: exception.record.errors.to_hash }, status: :unprocessable_content
    end

    def bad_request(exception)
      render json: { error: exception.message, code: "bad_request" }, status: :bad_request
    end
  end
end
