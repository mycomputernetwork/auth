if Rails.env.local?
  noted = Doorkeeper::Application.find_or_initialize_by(uid: "noted-development")
  noted.update!(
    name: "noted (development)",
    secret: "noted-development-secret",
    redirect_uri: "http://localhost:3000/auth/oidc/callback",
    backchannel_logout_uri: "http://localhost:3000/auth/backchannel_logout",
    scopes: "openid email profile offline_access",
    confidential: true
  )
end
