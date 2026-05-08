class ApiTokensController < ApplicationController
  def create
    @api_token, @raw_token = ApiToken.issue!(user: Current.user, name: token_params[:name].presence || "Android device")

    render :show, status: :created
  end

  private

  def token_params
    params.fetch(:api_token, {}).permit(:name)
  end
end
