require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join("spec/fixtures")]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before { OmniAuth.config.test_mode = true }
  config.after { OmniAuth.config.mock_auth.clear }
end

def google_auth(email:, uid: "google-#{email}", name: "Test User")
  OmniAuth::AuthHash.new(provider: "google_oauth2", uid: uid, info: { email: email, name: name })
end
