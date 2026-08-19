class JwtAccessToken
  def self.generate(attributes)
    now = attributes.fetch(:created_at).to_i
    application = attributes[:application]

    payload = {
      iss: Issuer.url,
      sub: attributes.fetch(:resource_owner_id).to_s,
      aud: application&.uid,
      exp: now + attributes.fetch(:expires_in).to_i,
      iat: now,
      jti: SecureRandom.uuid,
      scope: attributes.fetch(:scopes).to_s,
      sid: attributes[:sid],
    }.compact

    JWT.encode(payload, signing_key.keypair, algorithm, typ: "JWT", kid: signing_key.kid)
  end

  def self.signing_key = Doorkeeper::OpenidConnect.signing_key

  def self.algorithm = Doorkeeper::OpenidConnect.signing_algorithm.to_s
end
