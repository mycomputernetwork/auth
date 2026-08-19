if Rails.env.local?
  noted = Doorkeeper::Application.find_or_initialize_by(uid: "noted-development")
  noted.update!(
    name: "noted (development)",
    secret: "noted-development-secret",
    redirect_uri: "http://localhost:3000/auth/oidc/callback",
    backchannel_logout_uri: "http://localhost:3000/auth/backchannel_logout",
    post_logout_redirect_uri: "http://localhost:3000/sign_in",
    scopes: "openid email profile offline_access",
    confidential: true
  )

  native = Doorkeeper::Application.find_or_initialize_by(uid: "noted-native-development")
  native.update!(
    name: "noted native (development)",
    secret: nil,
    redirect_uri: "network.mycomputer.noted://oauth/callback",
    scopes: "openid email profile offline_access",
    confidential: false
  )
end
