class Issuer
  def self.url = ENV.fetch("AUTH_ISSUER") { Rails.application.config.x.issuer }
end
