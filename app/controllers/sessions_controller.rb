class SessionsController < ApplicationController
  skip_before_action :require_own_password

  def new
    redirect_to root_path if signed_in?
  end

  def password
    user = User.from_password(params[:email], params[:password])

    if user.nil?
      refuse "That email and password did not match."
    elsif user.revoked?
      refuse "That account's access has been revoked."
    else
      sign_in(user)
      redirect_to pop_return_to || root_path
    end
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

  private

  # Re-rendered rather than redirected so the address they typed survives.
  def refuse(message)
    @email = params[:email]
    flash.now[:alert] = message
    render :new, status: :unprocessable_content
  end
end
