lock "~> 3.19"

set :application, "auth"
set :repo_url, "https://github.com/mycomputernetwork/auth.git"
set :branch, "main"

# The signing key lives in credentials: a redeploy that lost it would invalidate
# every token in the fleet at once.
append :linked_files, "config/master.key", "config/credentials.yml.enc"
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "db_data"

set :keep_releases, 5

set :mise_ruby_version, "3.4.10"

set :default_env, {
  "PATH" => "$HOME/.local/share/mise/shims:$PATH",
  "RAILS_ENV" => "production",
  "AUTH_DB_PATH" => "/Users/prabhanshu/services/auth/shared/db_data",
  "RAILS_LOG_TO_STDOUT" => "true",
  "RAILS_SERVE_STATIC_FILES" => "true",
  # mise's Ruby is linked against a Homebrew OpenSSL whose cert.pem is not on
  # this machine, leaving it with no CA store: every outbound TLS call, Google's
  # token exchange included, fails to verify. Point it at the system store.
  "SSL_CERT_FILE" => "/etc/ssl/cert.pem"
}

set :bundle_path, -> { shared_path.join("vendor/bundle") }
set :bundle_flags, "--deployment --quiet"
set :bundle_without, %w[development test].join(" ")

SSHKit.config.command_map[:bundle] = "~/.local/bin/mise exec -- bundle"
SSHKit.config.command_map[:rake] = "~/.local/bin/mise exec -- bundle exec rake"
SSHKit.config.command_map[:rails] = "~/.local/bin/mise exec -- bundle exec rails"
