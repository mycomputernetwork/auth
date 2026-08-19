require "rails_helper"

RSpec.describe "RP-initiated logout" do
  let(:application) do
    Doorkeeper::Application.create!(
      name: "noted", uid: "noted-test", secret: "shhh",
      redirect_uri: "https://noted.example.com/auth/oidc/callback",
      post_logout_redirect_uri: "https://noted.example.com/sign_in",
      scopes: "openid"
    )
  end

  def sign_in
    post "/dev/sign_in", params: { email: "dev1@example.com" }
    Session.sole
  end

  def id_token(session, aud: application.uid, sid: session.sid, key: Doorkeeper::OpenidConnect.signing_key.keypair, iss: Issuer.url)
    JWT.encode({ iss: iss, aud: aud, sub: session.user_id, sid: sid,
                 iat: Time.current.to_i, exp: 2.minutes.from_now.to_i }, key, "RS256")
  end

  it "advertises the endpoint in discovery" do
    get "/.well-known/openid-configuration"

    expect(response.parsed_body["end_session_endpoint"]).to eq("http://www.example.com/oauth/logout")
  end

  it "ends auth's own session and returns to the client" do
    session = sign_in

    expect { get "/oauth/logout", params: { id_token_hint: id_token(session), post_logout_redirect_uri: application.post_logout_redirect_uri } }
      .to change(Session, :count).by(-1)

    expect(response).to redirect_to(application.post_logout_redirect_uri)
  end

  it "hands the client's state back" do
    session = sign_in

    get "/oauth/logout", params: {
      id_token_hint: id_token(session),
      post_logout_redirect_uri: application.post_logout_redirect_uri,
      state: "xyz"
    }

    expect(response).to redirect_to("#{application.post_logout_redirect_uri}?state=xyz")
  end

  it "accepts a client_id in place of an id token hint" do
    sign_in

    expect { get "/oauth/logout", params: { client_id: application.uid, post_logout_redirect_uri: application.post_logout_redirect_uri } }
      .to change(Session, :count).by(-1)

    expect(response).to redirect_to(application.post_logout_redirect_uri)
  end

  it "refuses to redirect to a URI the client never registered" do
    sign_in

    get "/oauth/logout", params: { client_id: application.uid, post_logout_redirect_uri: "https://evil.example.com/" }

    expect(response).to redirect_to(sign_in_url)
    expect(Session.count).to eq(0)
  end

  it "refuses to redirect on a hint it did not sign, but still signs out" do
    session = sign_in
    forged = id_token(session, key: OpenSSL::PKey::RSA.generate(2048))

    get "/oauth/logout", params: { id_token_hint: forged, post_logout_redirect_uri: application.post_logout_redirect_uri }

    expect(response).to redirect_to(sign_in_url)
    expect(Session.count).to eq(0)
  end

  it "leaves a session the hint does not name alone" do
    session = sign_in

    expect { get "/oauth/logout", params: { id_token_hint: id_token(session, sid: "some-other-sid"), post_logout_redirect_uri: application.post_logout_redirect_uri } }
      .not_to change(Session, :count)

    expect(response).to redirect_to(application.post_logout_redirect_uri)
  end

  it "accepts a hint whose id token has already expired" do
    session = sign_in
    expired = travel_to(1.hour.ago) { id_token(session) }

    expect { get "/oauth/logout", params: { id_token_hint: expired, post_logout_redirect_uri: application.post_logout_redirect_uri } }
      .to change(Session, :count).by(-1)
  end

  it "notifies the client's back channel on the way out" do
    session = sign_in
    application.update!(backchannel_logout_uri: "https://noted.example.com/auth/backchannel_logout")
    Doorkeeper::AccessToken.create!(application: application, resource_owner_id: session.user_id,
                                    sid: session.sid, scopes: "openid", expires_in: 900)
    stub = stub_request(:post, application.backchannel_logout_uri).to_return(status: 200)

    get "/oauth/logout", params: { id_token_hint: id_token(session), post_logout_redirect_uri: application.post_logout_redirect_uri }

    expect(stub).to have_been_requested
  end

  it "redirects a visitor who is already signed out" do
    get "/oauth/logout", params: { client_id: application.uid, post_logout_redirect_uri: application.post_logout_redirect_uri }

    expect(response).to redirect_to(application.post_logout_redirect_uri)
  end
end
