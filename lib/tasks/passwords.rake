namespace :auth do
  desc "Set or reset a password: rake auth:set_password[someone@example.com] — prints a one-time password"
  task :set_password, %i[email password] => :environment do |_task, args|
    email = args.fetch(:email).strip.downcase
    abort "#{email} is not on the allowlist" unless AllowedEmail.allows?(email)

    password = args[:password].presence || SecureRandom.alphanumeric(20)
    user = User.find_or_initialize_by(email: email)
    user.password = password
    user.password_changed_at = nil
    user.save!

    puts "one-time password for #{email}: #{password}"
    puts "they are made to pick their own on first sign-in, after which you will not know it"
    puts "their existing sessions are untouched; end them with User.find_by(email: …).sessions.destroy_all" if user.sessions.any?
  end

  desc "Remove a password, leaving only Google sign-in: rake auth:clear_password[someone@example.com]"
  task :clear_password, [:email] => :environment do |_task, args|
    user = User.find_by(email: args.fetch(:email).strip.downcase) or abort "no such user"
    user.update!(password_digest: nil)

    puts "password cleared for #{user.email}"
  end
end
