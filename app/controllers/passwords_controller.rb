class PasswordsController < ApplicationController
  skip_before_action :require_own_password

  before_action :require_sign_in

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.change_password(params[:password], params[:password_confirmation])
      redirect_to pop_return_to || root_path, notice: "Password changed."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def require_sign_in
    redirect_to sign_in_path unless signed_in?
  end
end
