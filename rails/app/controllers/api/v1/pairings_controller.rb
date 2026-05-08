module Api
  module V1
    class PairingsController < BaseController
      skip_before_action :authenticate_api_token!

      def create
        claimed = PairingSession.claim!(
          raw_code: pairing_params.fetch(:code),
          device_name: pairing_params[:device_name]
        )

        if claimed
          pairing_session, raw_token = claimed
          broadcast_pairing_success(pairing_session)

          render json: {
            data: {
              type: "pairing",
              attributes: {
                api_token: raw_token,
                token_type: "Bearer",
                long_lived: true,
                user_email: pairing_session.user.email_address
              }
            }
          }, status: :created
        else
          render json: { error: "Pairing code is invalid, expired, or already used.", code: "invalid_pairing_code" },
            status: :unprocessable_content
        end
      end

      private

      def broadcast_pairing_success(pairing_session)
        Turbo::StreamsChannel.broadcast_stream_to(
          pairing_session,
          content: %(<turbo-stream action="redirect" url="#{ERB::Util.html_escape(candidate_potholes_path)}"></turbo-stream>)
        )
      end

      def pairing_params
        params.require(:pairing).permit(:code, :device_name)
      end
    end
  end
end
