module Oauth
  class EndSessionsController < ApplicationController
    # Signing out must work even for someone who owes us a password.
    skip_before_action :require_own_password

    def show
      end_session = EndSession.new(params)
      sign_out if current_session && end_session.ends?(current_session)

      if (url = end_session.redirect_url)
        redirect_to url, allow_other_host: true
      else
        redirect_to sign_in_url, notice: "Signed out."
      end
    end
  end
end
