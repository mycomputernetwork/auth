google = Rails.application.credentials.google || {}

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, google[:client_id], google[:client_secret],
           scope: "email,profile",
           prompt: "select_account",
           access_type: "online"
end

OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.on_failure = proc { |env| SessionsController.action(:failure).call(env) }
