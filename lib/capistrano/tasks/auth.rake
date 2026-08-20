namespace :auth do
  desc "Upload the master key on first deploy"
  task :setup_master_key do
    on roles(:app) do
      next if test("[ -f #{shared_path}/config/master.key ]")

      execute :mkdir, "-p", "#{shared_path}/config"
      if File.exist?("config/master.key")
        upload! "config/master.key", "#{shared_path}/config/master.key"
      else
        warn "config/master.key not found locally; put it on the server by hand before deploying"
      end
    end
  end

  desc "Upload the encrypted credentials on first deploy"
  task :setup_credentials do
    on roles(:app) do
      next if test("[ -f #{shared_path}/config/credentials.yml.enc ]")

      execute :mkdir, "-p", "#{shared_path}/config"
      upload! "config/credentials.yml.enc", "#{shared_path}/config/credentials.yml.enc"
    end
  end

  desc "Prepare the database"
  task :db_prepare do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute "~/.local/bin/mise", "exec", "--", "bundle", "exec", "rails", "db:prepare"
        end
      end
    end
  end

  desc "Precompile assets"
  task :assets_precompile do
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute "~/.local/bin/mise", "exec", "--", "bundle", "exec", "rails", "assets:precompile"
        end
      end
    end
  end

  desc "Create the launchd plist"
  task :setup_launchd do
    on roles(:app) do
      home = capture("echo $HOME").strip
      plist_path = "#{home}/Library/LaunchAgents/com.auth.app.plist"
      execute :mkdir, "-p", "#{home}/Library/LaunchAgents"

      plist = <<~PLIST
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>com.auth.app</string>

          <key>ProgramArguments</key>
          <array>
            <string>#{home}/.local/bin/mise</string>
            <string>exec</string>
            <string>--</string>
            <string>bundle</string>
            <string>exec</string>
            <string>puma</string>
            <string>-C</string>
            <string>config/puma.rb</string>
          </array>

          <key>WorkingDirectory</key>
          <string>#{current_path}</string>

          <key>EnvironmentVariables</key>
          <dict>
            <key>RAILS_ENV</key>
            <string>production</string>
            <key>AUTH_DB_PATH</key>
            <string>#{shared_path}/db_data</string>
            <key>RAILS_LOG_TO_STDOUT</key>
            <string>true</string>
            <key>RAILS_SERVE_STATIC_FILES</key>
            <string>true</string>
            <key>PORT</key>
            <string>3001</string>
            <key>SSL_CERT_FILE</key>
            <string>/etc/ssl/cert.pem</string>
          </dict>

          <key>RunAtLoad</key>
          <true/>

          <key>KeepAlive</key>
          <true/>

          <key>StandardOutPath</key>
          <string>#{shared_path}/log/launchd.out.log</string>

          <key>StandardErrorPath</key>
          <string>#{shared_path}/log/launchd.err.log</string>
        </dict>
        </plist>
      PLIST

      upload! StringIO.new(plist), plist_path
      execute "launchctl", "unload", plist_path rescue nil
      execute "launchctl", "load", plist_path
      info "launchd service loaded at #{plist_path}"
    end
  end

  desc "Restart the application"
  task :restart do
    on roles(:app) do
      execute "launchctl", "kickstart", "-k", "gui/#{capture(:id, '-u')}/com.auth.app"
    end
  end

  desc "Stop the application"
  task :stop do
    on roles(:app) do
      execute "launchctl", "stop", "com.auth.app" rescue nil
    end
  end

  desc "Check application status"
  task :status do
    on roles(:app) do
      info "Status: #{capture("launchctl list | grep com.auth.app || echo 'Not running'")}"
    end
  end
end

before "deploy:check:linked_files", "auth:setup_master_key"
before "deploy:check:linked_files", "auth:setup_credentials"
after "deploy:migrate", "auth:db_prepare"
after "auth:db_prepare", "auth:assets_precompile"
after "deploy:publishing", "auth:setup_launchd"
after "deploy:publishing", "auth:restart"
