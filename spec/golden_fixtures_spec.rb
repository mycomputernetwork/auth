require "rails_helper"

# Freezes real auth tokens into spec/fixtures/golden.json, the reference a
# downstream stub is checked against. Excluded from the suite by its :golden tag;
# regenerate deliberately, then copy into a client:
#
#   bundle exec rspec spec/golden_fixtures_spec.rb --tag golden
#   bundle exec rake "auth:golden_fixtures[../noted]"
RSpec.describe "Golden fixtures", :golden, type: :request do
  let(:verifier) { SecureRandom.urlsafe_base64(64) }
  let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }
  let(:scope) { "openid email profile offline_access" }

  let(:application) do
    Doorkeeper::Application.create!(
      name: "noted", uid: "noted-golden", secret: "shhh",
      redirect_uri: "https://noted.example.com/auth/oidc/callback",
      backchannel_logout_uri: "https://noted.example.com/auth/backchannel_logout",
      scopes: scope
    )
  end

  def exchange
    get "/oauth/authorize", params: {
      client_id: application.uid, redirect_uri: application.redirect_uri,
      response_type: "code", scope: scope,
      code_challenge: challenge, code_challenge_method: "S256"
    }
    code = Rack::Utils.parse_query(URI(response.location).query).fetch("code")

    post "/oauth/token", params: {
      grant_type: "authorization_code", code: code,
      redirect_uri: application.redirect_uri, client_id: application.uid,
      client_secret: application.secret, code_verifier: verifier
    }
    response.parsed_body
  end

  it "mints the fixtures" do
    travel_to Time.utc(2026, 1, 1, 12, 0, 0)

    post "/dev/sign_in", params: { email: "dev1@example.com" }
    session = Session.sole
    tokens = exchange

    get "/oauth/discovery/keys"
    jwks = response.parsed_body

    logout_token = LogoutToken.new(
      application: application, subject: session.user_id, sid: session.sid
    ).to_jwt

    fixtures = {
      issuer: Issuer.url,
      audience: application.uid,
      subject: session.user_id,
      email: "dev1@example.com",
      name: "Dev user 1",
      sid: session.sid,
      minted_at: Time.now.to_i,
      jwks: jwks,
      access_token: tokens.fetch("access_token"),
      id_token: tokens.fetch("id_token"),
      logout_token: logout_token
    }

    path = Rails.root.join("spec/fixtures/golden.json")
    path.write(JSON.pretty_generate(fixtures) + "\n")

    expect(path).to exist
  end
end
