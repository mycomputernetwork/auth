class HomeController < ApplicationController
  def show
    redirect_to sign_in_path unless signed_in?
  end
end
