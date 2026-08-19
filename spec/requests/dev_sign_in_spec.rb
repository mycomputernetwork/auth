require "rails_helper"

RSpec.describe "Development sign-in" do
  it "signs in a fixture user" do
    expect { post "/dev/sign_in", params: { email: "dev1@example.com" } }
      .to change(Session, :count).by(1)
    expect(response).to redirect_to("/")
  end

  it "refuses a fixture that is not allowlisted" do
    expect { post "/dev/sign_in", params: { email: "dev3@example.com" } }
      .not_to change(Session, :count)
  end

  it "refuses a revoked fixture" do
    expect { post "/dev/sign_in", params: { email: "dev4@example.com" } }
      .not_to change(Session, :count)
  end
end
