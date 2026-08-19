module Dev
  class SessionsController < ApplicationController
    before_action :ensure_local

    def new
      @users = DevUsers.all
    end

    def create
      user = DevUsers.provision(params[:email])

      if user.nil?
        redirect_to dev_sign_in_path, alert: "Not on the allowlist."
      elsif user.revoked?
        redirect_to dev_sign_in_path, alert: "Access revoked."
      else
        sign_in(user)
        redirect_to pop_return_to || root_path
      end
    end

    private

    def ensure_local
      head :not_found unless Rails.env.local?
    end
  end
end
