class PairingSessionsController < ApplicationController
  def create
    @pairing_session, @raw_code = PairingSession.issue_for!(Current.user)
    @pairing_payload = @pairing_session.pairing_payload(raw_code: @raw_code, api_base_url: api_base_url)

    render :show, status: :created
  end

  private

  def api_base_url
    ENV.fetch("POTDROID_API_BASE_URL") { request.base_url }
  end
end
