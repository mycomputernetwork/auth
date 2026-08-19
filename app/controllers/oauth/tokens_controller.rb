module Oauth
  class TokensController < Doorkeeper::TokensController
    before_action :reject_revoked_owner, only: :create

    private

    def reject_revoked_owner
      return unless params[:grant_type] == "refresh_token"

      token = Doorkeeper::AccessToken.by_refresh_token(params[:refresh_token])
      return if token.nil? || User.active.exists?(id: token.resource_owner_id)

      render json: { error: "invalid_grant" }, status: :bad_request
    end
  end
end
