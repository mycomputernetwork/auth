class SessionsController < ApplicationController
  def new
    redirect_to root_path if signed_in?
  end

  def create
    user = User.from_google(request.env["omniauth.auth"])

    if user.nil?
      redirect_to sign_in_path, alert: "That account is not allowed to sign in."
    elsif user.revoked?
      redirect_to sign_in_path, alert: "That account's access has been revoked."
    else
      sign_in(user)
      redirect_to pop_return_to || root_path
    end
  end

  def failure
    redirect_to sign_in_path, alert: "Sign-in with Google failed."
  end

  def destroy
    sign_out
    redirect_to sign_in_path, notice: "Signed out."
  end
end
