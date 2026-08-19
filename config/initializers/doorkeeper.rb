Doorkeeper.configure do
  orm :active_record

  resource_owner_authenticator do
    if current_session
      current_user
    else
      store_return_to(request.fullpath)
      redirect_to(Rails.env.local? ? dev_sign_in_path : sign_in_path)
    end
  end

  admin_authenticator { head :not_found }

  access_token_generator "JwtAccessToken"
  custom_access_token_attributes [:sid]

  access_token_expires_in 15.minutes
  use_refresh_token

  grant_flows %w[authorization_code]
  force_pkce
  skip_authorization { true }

  default_scopes :openid
  optional_scopes :email, :profile, :offline_access

  base_controller "ApplicationController"

  allow_blank_redirect_uri false
  force_ssl_in_redirect_uri !Rails.env.local?
end
