class PairingSessionsController < ApplicationController
  def show
    @pairing_session = Current.user.pairing_sessions.find(params[:id])

    if @pairing_session.claimed?
      redirect_to candidate_potholes_path, notice: "Android app paired."
      return
    end

    unless @pairing_session.active?
      redirect_to candidate_potholes_path, alert: "Pairing session expired. Start a new one."
      return
    end

    @raw_code = stored_pairing_code(@pairing_session)
    unless @raw_code
      redirect_to candidate_potholes_path, alert: "Pairing code is no longer available. Start a new pairing session."
      return
    end

    assign_pairing_view_state
  end

  def create
    @pairing_session, @raw_code = PairingSession.issue_for!(Current.user)
    store_pairing_code(@pairing_session, @raw_code)

    redirect_to pairing_session_path(@pairing_session), status: :see_other
  end

  private

  def assign_pairing_view_state
    @api_base_url = api_base_url
    @pairing_payload = @pairing_session.pairing_payload(raw_code: @raw_code, api_base_url: @api_base_url)
  end

  def store_pairing_code(pairing_session, raw_code)
    session[:pairing_codes] ||= {}
    session[:pairing_codes][pairing_session.id.to_s] = raw_code
  end

  def stored_pairing_code(pairing_session)
    session.dig(:pairing_codes, pairing_session.id.to_s)
  end

  def api_base_url
    ENV.fetch("POTDROID_API_BASE_URL") { request.base_url }
  end
end
