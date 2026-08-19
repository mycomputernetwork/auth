namespace :auth do
  desc "Register a confidential client: rake auth:register_client[noted,https://noted.mycomputer.network]"
  task :register_client, %i[name base_url] => :environment do |_task, args|
    base = args.fetch(:base_url).chomp("/")
    abort "base_url must use https" unless URI(base).is_a?(URI::HTTPS)

    application = Doorkeeper::Application.create!(
      name: args.fetch(:name),
      redirect_uri: "#{base}/auth/oidc/callback",
      backchannel_logout_uri: "#{base}/auth/backchannel_logout",
      post_logout_redirect_uri: "#{base}/sign_in",
      scopes: "openid email profile offline_access",
      confidential: true
    )

    puts "uid:    #{application.uid}"
    puts "secret: #{application.secret}"
  end

  desc "Register a public PKCE client: rake auth:register_native_client[noted-android,network.mycomputer.noted://oauth/callback]"
  task :register_native_client, %i[name redirect_uri] => :environment do |_task, args|
    application = Doorkeeper::Application.create!(
      name: args.fetch(:name),
      redirect_uri: args.fetch(:redirect_uri),
      scopes: "openid email profile offline_access",
      confidential: false
    )

    puts "uid: #{application.uid}"
  end
end
