module Oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    private

    def pre_auth_params
      current_session ? super.merge(sid: current_session.sid) : super
    end
  end
end
