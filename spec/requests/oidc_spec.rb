require "rails_helper"

RSpec.describe "The OIDC provider" do
  let(:verifier) { SecureRandom.urlsafe_base64(64) }
  let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }

  let(:application) do
    Doorkeeper::Application.create!(
      name: "noted", uid: "noted-test", secret: "shhh",
      redirect_uri: "https://noted.example.com/auth/oidc/callback",
      scopes: "openid email profile offline_access"
    )
  end

  def sign_in
    post "/dev/sign_in", params: { email: "family@example.com" }
    Session.sole
  end

  def authorization_code
    get "/oauth/authorize", params: {
      client_id: application.uid,
      redirect_uri: application.redirect_uri,
      response_type: "code",
      scope: "openid email profile offline_access",
      code_challenge: challenge,
      code_challenge_method: "S256",
      state: "xyz"
    }
    Rack::Utils.parse_query(URI(response.location).query).fetch("code")
  end

  def exchange(code)
    post "/oauth/token", params: {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: application.redirect_uri,
      client_id: application.uid,
      client_secret: application.secret,
      code_verifier: verifier
    }
    response.parsed_body
  end

  def refresh(refresh_token)
    post "/oauth/token", params: {
      grant_type: "refresh_token",
      refresh_token: refresh_token,
      client_id: application.uid,
      client_secret: application.secret
    }
    response.parsed_body
  end

  def decode(jwt)
    JWT.decode(jwt, Doorkeeper::OpenidConnect.signing_key.keypair.public_key, true, algorithm: "RS256").first
  end

  it "publishes a discovery document" do
    get "/.well-known/openid-configuration"

    expect(response.parsed_body).to include(
      "issuer" => "http://www.example.com",
      "jwks_uri" => "http://www.example.com/oauth/discovery/keys",
      "authorization_endpoint" => "http://www.example.com/oauth/authorize",
      "token_endpoint" => "http://www.example.com/oauth/token"
    )
    expect(response.parsed_body["code_challenge_methods_supported"]).to include("S256")
  end

  it "publishes a public JWKS" do
    get "/oauth/discovery/keys"
    key = response.parsed_body.fetch("keys").sole

    expect(key).to include("kty" => "RSA", "use" => "sig", "alg" => "RS256")
    expect(key.keys).to include("kid", "n", "e")
    expect(key.keys).not_to include("d", "p", "q")
  end

  it "sends an unauthenticated authorize request to sign-in" do
    get "/oauth/authorize", params: {
      client_id: application.uid, redirect_uri: application.redirect_uri,
      response_type: "code", scope: "openid",
      code_challenge: challenge, code_challenge_method: "S256"
    }

    expect(response).to redirect_to("/dev/sign_in")
  end

  it "issues a JWT access token and an ID token for a PKCE exchange" do
    session = sign_in
    tokens = exchange(authorization_code)

    expect(tokens["token_type"]).to eq("Bearer")
    expect(tokens["expires_in"]).to eq(900)

    access = decode(tokens.fetch("access_token"))
    expect(access).to include(
      "iss" => "http://www.example.com",
      "sub" => User.sole.id.to_s,
      "aud" => application.uid,
      "sid" => session.sid,
      "scope" => "openid email profile offline_access"
    )
    expect(access["exp"] - access["iat"]).to eq(900)

    id_token = decode(tokens.fetch("id_token"))
    expect(id_token).to include(
      "iss" => "http://www.example.com",
      "sub" => User.sole.id.to_s,
      "aud" => application.uid,
      "sid" => session.sid,
      "email" => "family@example.com",
      "email_verified" => true,
      "name" => "Family Member"
    )
  end

  it "rejects an exchange with the wrong code verifier" do
    sign_in
    code = authorization_code

    post "/oauth/token", params: {
      grant_type: "authorization_code", code: code,
      redirect_uri: application.redirect_uri, client_id: application.uid,
      client_secret: application.secret, code_verifier: "wrong"
    }

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to eq("invalid_grant")
  end

  it "issues a second token silently once auth's own session exists" do
    sign_in
    exchange(authorization_code)

    other = Doorkeeper::Application.create!(
      name: "chat", uid: "chat-test", secret: "shhh",
      redirect_uri: "https://chat.example.com/callback", scopes: "openid"
    )
    get "/oauth/authorize", params: {
      client_id: other.uid, redirect_uri: other.redirect_uri,
      response_type: "code", scope: "openid",
      code_challenge: challenge, code_challenge_method: "S256"
    }

    expect(response.location).to start_with(other.redirect_uri)
  end

  it "rotates the refresh token and keeps the session id" do
    session = sign_in
    tokens = exchange(authorization_code)

    rotated = refresh(tokens.fetch("refresh_token"))

    expect(rotated["refresh_token"]).to be_present
    expect(rotated["refresh_token"]).not_to eq(tokens["refresh_token"])
    expect(decode(rotated.fetch("access_token"))).to include("sid" => session.sid)
    expect(Doorkeeper::AccessToken.by_token(tokens["access_token"])).to be_revoked
  end

  it "refuses to refresh once the user is revoked" do
    sign_in
    tokens = exchange(authorization_code)

    User.sole.revoke!

    expect(refresh(tokens.fetch("refresh_token"))["error"]).to eq("invalid_grant")
  end

  it "serves userinfo for a live access token" do
    sign_in
    tokens = exchange(authorization_code)

    get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{tokens.fetch("access_token")}" }

    expect(response.parsed_body).to include("sub" => User.sole.id.to_s, "email" => "family@example.com")
  end
end

RSpec.describe "A public native client" do
  let(:verifier) { SecureRandom.urlsafe_base64(64) }
  let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }

  let(:application) do
    Doorkeeper::Application.create!(
      name: "noted android", uid: "noted-android", secret: nil,
      redirect_uri: "network.mycomputer.noted://oauth/callback",
      scopes: "openid email offline_access", confidential: false
    )
  end

  it "exchanges a code with PKCE and no client secret" do
    post "/dev/sign_in", params: { email: "family@example.com" }

    get "/oauth/authorize", params: {
      client_id: application.uid, redirect_uri: application.redirect_uri,
      response_type: "code", scope: "openid email offline_access",
      code_challenge: challenge, code_challenge_method: "S256"
    }
    code = Rack::Utils.parse_query(URI(response.location).query).fetch("code")

    post "/oauth/token", params: {
      grant_type: "authorization_code", code: code,
      redirect_uri: application.redirect_uri, client_id: application.uid,
      code_verifier: verifier
    }

    expect(response.parsed_body).to include("token_type" => "Bearer")
    expect(response.parsed_body["refresh_token"]).to be_present
  end
end
