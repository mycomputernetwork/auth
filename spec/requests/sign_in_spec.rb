require "rails_helper"

RSpec.describe "Signing in with Google" do
  def callback(auth)
    OmniAuth.config.mock_auth[:google_oauth2] = auth
    post "/auth/google_oauth2/callback", env: { "omniauth.auth" => auth }
  end

  it "signs in an allowlisted email and creates a session row" do
    AllowedEmail.create!(email: "family@example.com")

    expect { callback(google_auth(email: "family@example.com")) }
      .to change(User, :count).by(1).and change(Session, :count).by(1)

    expect(response).to redirect_to("/")
    follow_redirect!
    expect(response.body).to include("family@example.com")
  end

  it "turns away an email that is not allowlisted" do
    expect { callback(google_auth(email: "stranger@example.com")) }.not_to change(User, :count)
    expect(response).to redirect_to("/sign_in")
  end

  it "turns away a revoked user" do
    AllowedEmail.create!(email: "family@example.com")
    User.create!(email: "family@example.com", google_sub: "google-family@example.com", revoked_at: Time.current)

    expect { callback(google_auth(email: "family@example.com")) }.not_to change(Session, :count)
    expect(response).to redirect_to("/sign_in")
  end

  it "keeps the identity when a Google account is re-linked" do
    AllowedEmail.create!(email: "family@example.com")
    callback(google_auth(email: "family@example.com", uid: "old-sub"))
    user = User.sole

    callback(google_auth(email: "family@example.com", uid: "new-sub"))

    expect(User.sole.id).to eq(user.id)
    expect(User.sole.google_sub).to eq("new-sub")
  end

  it "drops the session on logout" do
    AllowedEmail.create!(email: "family@example.com")
    callback(google_auth(email: "family@example.com"))

    expect { delete "/logout" }.to change(Session, :count).by(-1)
    get "/"
    expect(response).to redirect_to("/sign_in")
  end
end
