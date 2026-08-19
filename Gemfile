source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1.3", ">= 8.1.3.1"
gem "propshaft"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false

gem "doorkeeper", "~> 5.8"
gem "doorkeeper-openid_connect", "~> 1.8"
gem "omniauth-google-oauth2", "~> 1.2"
gem "omniauth-rails_csrf_protection", "~> 1.0"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails", "~> 8.0"
end

group :development do
  gem "capistrano", "~> 3.19", require: false
  gem "capistrano-rails", "~> 1.7", require: false
  gem "capistrano-bundler", "~> 2.1", require: false
end
