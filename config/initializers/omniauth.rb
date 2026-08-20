google = Rails.application.credentials.google || {}

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, google[:client_id], google[:client_secret],
           scope: "email,profile",
           prompt: "select_account",
           access_type: "online"
end

# GET so a client naming Google can be redirected straight there, with no page
# in between to carry a CSRF token. Starting a sign-in is not a state change:
# the callback still verifies `state` against this session, so a forged request
# phase can produce an unexpected Google screen and nothing else.
OmniAuth.config.allowed_request_methods = [:get]
OmniAuth.config.request_validation_phase = ->(_env) {}
OmniAuth.config.on_failure = proc { |env| SessionsController.action(:failure).call(env) }
