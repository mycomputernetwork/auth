require "rails_helper"

RSpec.describe "Changing a password" do
  before { AllowedEmail.create!(email: "dev1@example.com") }

  def sign_in_with(password)
    post "/sign_in", params: { email: "dev1@example.com", password: password }
  end

  context "when an administrator handed the password over" do
    let!(:user) { User.create!(email: "dev1@example.com", password: "issued-by-admin") }

    it "sends them to pick their own before anything else" do
      sign_in_with("issued-by-admin")

      get "/"
      expect(response).to redirect_to("/password")
    end

    it "lets them through once they have picked one" do
      sign_in_with("issued-by-admin")
      patch "/password", params: { password: "a phrase they chose", password_confirmation: "a phrase they chose" }

      get "/"
      expect(response).to have_http_status(:ok)
      expect(user.reload.password_changed_at).to be_present
    end

    it "signs them in afterwards with the new password, not the issued one" do
      sign_in_with("issued-by-admin")
      patch "/password", params: { password: "a phrase they chose", password_confirmation: "a phrase they chose" }
      delete "/logout"

      sign_in_with("issued-by-admin")
      expect(response).to have_http_status(:unprocessable_content)

      sign_in_with("a phrase they chose")
      expect(response).to redirect_to("/")
    end

    it "refuses a password that is too short, and one that does not match itself" do
      sign_in_with("issued-by-admin")

      patch "/password", params: { password: "short", password_confirmation: "short" }
      expect(response).to have_http_status(:unprocessable_content)

      patch "/password", params: { password: "a phrase they chose", password_confirmation: "mistyped entirely" }
      expect(response).to have_http_status(:unprocessable_content)

      expect(user.reload.password_changed_at).to be_nil
    end

    it "still lets them sign out" do
      sign_in_with("issued-by-admin")

      expect { delete "/logout" }.to change(Session, :count).by(-1)
    end

    it "does not let them collect an authorization code first" do
      application = Doorkeeper::Application.create!(
        name: "noted", uid: "noted-test", secret: "shhh",
        redirect_uri: "https://noted.example.com/auth/oidc/callback",
        scopes: "openid"
      )
      sign_in_with("issued-by-admin")

      get "/oauth/authorize", params: {
        client_id: application.uid, redirect_uri: application.redirect_uri,
        response_type: "code", scope: "openid",
        code_challenge: "x", code_challenge_method: "plain"
      }

      expect(response).to redirect_to("/password")
    end
  end

  it "names the account in the form so a password manager files it correctly" do
    User.create!(email: "dev1@example.com", password: "the one they chose", password_changed_at: 1.day.ago)
    sign_in_with("the one they chose")

    get "/password"
    expect(response.body).to include('autocomplete="username"', 'value="dev1@example.com"')
  end

  it "changes the signed-in account whatever address the form carries" do
    User.create!(email: "dev1@example.com", password: "issued-by-admin")
    other = User.create!(email: "someone-else@example.com", password: "theirs to keep")
    sign_in_with("issued-by-admin")

    patch "/password", params: {
      email: other.email, password: "a phrase they chose", password_confirmation: "a phrase they chose"
    }

    expect(other.reload.authenticate("theirs to keep")).to be_truthy
    expect(User.find_by(email: "dev1@example.com").authenticate("a phrase they chose")).to be_truthy
  end

  it "leaves a Google-only account alone" do
    post "/dev/sign_in", params: { email: "dev1@example.com" }

    get "/"
    expect(response).to have_http_status(:ok)
  end

  it "lets someone change a password they already chose" do
    User.create!(email: "dev1@example.com", password: "the one they chose", password_changed_at: 1.day.ago)
    sign_in_with("the one they chose")

    get "/password"
    expect(response).to have_http_status(:ok)
  end
end
