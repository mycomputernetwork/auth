require "rails_helper"

RSpec.describe "Back-channel logout" do
  let(:noted) do
    Doorkeeper::Application.create!(
      name: "noted", uid: "noted-test", secret: "shhh",
      redirect_uri: "https://noted.example.com/auth/oidc/callback",
      backchannel_logout_uri: "https://noted.example.com/auth/backchannel_logout",
      scopes: "openid"
    )
  end

  let(:chat) do
    Doorkeeper::Application.create!(
      name: "chat", uid: "chat-test", secret: "shhh",
      redirect_uri: "https://chat.example.com/auth/oidc/callback",
      backchannel_logout_uri: "https://chat.example.com/auth/backchannel_logout",
      scopes: "openid"
    )
  end

  def sign_in
    post "/dev/sign_in", params: { email: "dev1@example.com" }
    Session.sole
  end

  def token_for(application, session)
    Doorkeeper::AccessToken.create!(
      application: application, resource_owner_id: session.user_id,
      sid: session.sid, scopes: "openid", expires_in: 900
    )
  end

  def decode(jwt)
    JWT.decode(jwt, Doorkeeper::OpenidConnect.signing_key.keypair.public_key, true, algorithm: "RS256")
  end

  it "posts a logout token to every app holding a live token for the session" do
    session = sign_in
    token_for(noted, session)
    token_for(chat, session)
    stubs = [noted, chat].map { |app| stub_request(:post, app.backchannel_logout_uri).to_return(status: 200) }

    delete "/logout"

    stubs.each { |stub| expect(stub).to have_been_requested }
    expect(LogoutDelivery.pluck(:status)).to eq(%w[delivered delivered])
  end

  it "signs a logout token the app can verify" do
    session = sign_in
    token_for(noted, session)
    posted = nil
    stub_request(:post, noted.backchannel_logout_uri)
      .with { |request| posted = Rack::Utils.parse_query(request.body)["logout_token"] }
      .to_return(status: 200)

    delete "/logout"
    claims, header = decode(posted)

    expect(header).to include("typ" => "logout+jwt", "alg" => "RS256")
    expect(claims).to include(
      "iss" => "http://www.example.com",
      "aud" => noted.uid,
      "sub" => session.user_id.to_s,
      "sid" => session.sid
    )
    expect(claims["events"]).to eq(LogoutToken::EVENT => {})
    expect(claims).not_to include("nonce")
  end

  it "skips apps with no live token for that session" do
    session = sign_in
    token_for(noted, session)
    chat
    stub_request(:post, noted.backchannel_logout_uri).to_return(status: 200)

    delete "/logout"

    expect(LogoutDelivery.sole.application).to eq(noted)
  end

  it "records a delivery that the app rejected" do
    session = sign_in
    token_for(noted, session)
    stub_request(:post, noted.backchannel_logout_uri).to_return(status: 500)

    delete "/logout"

    expect(LogoutDelivery.sole).to have_attributes(status: "rejected", detail: "HTTP 500")
  end

  it "records a delivery that never arrived, and still ends the session" do
    session = sign_in
    token_for(noted, session)
    stub_request(:post, noted.backchannel_logout_uri).to_timeout

    expect { delete "/logout" }.to change(Session, :count).by(-1)

    expect(LogoutDelivery.sole).to have_attributes(status: "failed")
    expect(LogoutDelivery.failed.count).to eq(1)
  end

  it "revokes the session's access tokens so a refresh cannot outlive the logout" do
    session = sign_in
    token = token_for(noted, session)
    stub_request(:post, noted.backchannel_logout_uri).to_return(status: 200)

    delete "/logout"

    expect(token.reload).to be_revoked
  end

  it "logs every session out when a user is revoked" do
    session = sign_in
    token_for(noted, session)
    stub = stub_request(:post, noted.backchannel_logout_uri).to_return(status: 200)

    User.sole.revoke!

    expect(stub).to have_been_requested
    expect(LogoutDelivery.sole.sid).to eq(session.sid)
  end
end
