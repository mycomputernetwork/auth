Rails.application.routes.draw do
  use_doorkeeper do
    controllers authorizations: "oauth/authorizations", tokens: "oauth/tokens"
    skip_controllers :applications, :authorized_applications
  end
  use_doorkeeper_openid_connect
  root "home#show"

  get "sign_in", to: "sessions#new", as: :sign_in
  match "auth/google_oauth2/callback", to: "sessions#create", via: %i[get post]
  get "auth/failure", to: "sessions#failure"
  match "logout", to: "sessions#destroy", via: %i[get delete], as: :logout

  if Rails.env.local?
    get "dev/sign_in", to: "dev/sessions#new", as: :dev_sign_in
    post "dev/sign_in", to: "dev/sessions#create"
  end

  get "up", to: "rails/health#show", as: :rails_health_check
end
