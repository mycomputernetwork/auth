class DevUsers
  class NotAvailable < StandardError; end

  def self.all
    raise NotAvailable unless Rails.env.local?

    @all ||= YAML.load_file(Rails.root.join("config/dev_users.yml")).map(&:symbolize_keys)
  end

  def self.find(email) = all.find { |u| u[:email] == email }

  def self.provision(email)
    fixture = find(email) or return nil
    AllowedEmail.find_or_create_by!(email: fixture[:email]) if fixture[:allowed]
    return nil unless AllowedEmail.allows?(fixture[:email])

    user = User.find_or_initialize_by(email: fixture[:email])
    user.google_sub ||= "dev-#{Digest::MD5.hexdigest(fixture[:email])}"
    user.name = fixture[:name]
    user.revoked_at ||= Time.current if fixture[:revoked]
    user.save!
    user
  end
end
