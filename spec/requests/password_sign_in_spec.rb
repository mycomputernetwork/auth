require "rails_helper"

RSpec.describe "Signing in with a password" do
  def sign_in(email:, password:)
    post "/sign_in", params: { email: email, password: password }
  end

  before { AllowedEmail.create!(email: "dev1@example.com") }

  it "signs in a user whose password matches" do
    User.create!(email: "dev1@example.com", password: "correct-horse-battery")

    expect { sign_in(email: "DEV1@example.com", password: "correct-horse-battery") }
      .to change(Session, :count).by(1)

    expect(response).to redirect_to("/")
  end

  it "turns away a wrong password" do
    User.create!(email: "dev1@example.com", password: "correct-horse-battery")

    expect { sign_in(email: "dev1@example.com", password: "wrong") }.not_to change(Session, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "hands back the address they typed so it need not be retyped" do
    sign_in(email: "dev1@example.com", password: "wrong")

    expect(response.body).to include('value="dev1@example.com"')
    expect(response.body).to include("That email and password did not match.")
  end

  it "turns away a Google account that has no password set" do
    User.create!(email: "dev1@example.com", google_sub: "google-dev1")

    expect { sign_in(email: "dev1@example.com", password: "any-guess-at-all") }
      .not_to change(Session, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "turns away a blank password" do
    User.create!(email: "dev1@example.com", password: "correct-horse-battery")

    expect { sign_in(email: "dev1@example.com", password: "") }.not_to change(Session, :count)
  end

  it "turns away an email that is not allowlisted" do
    AllowedEmail.find_by(email: "dev1@example.com").destroy
    User.create!(email: "dev1@example.com", password: "correct-horse-battery")

    expect { sign_in(email: "dev1@example.com", password: "correct-horse-battery") }
      .not_to change(Session, :count)
  end

  it "turns away a revoked user" do
    User.create!(email: "dev1@example.com", password: "correct-horse-battery", revoked_at: Time.current)

    expect { sign_in(email: "dev1@example.com", password: "correct-horse-battery") }
      .not_to change(Session, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end
end
