class LogoutToken
  EVENT = "http://schemas.openid.net/event/backchannel-logout".freeze

  def initialize(application:, subject:, sid:)
    @application = application
    @subject = subject
    @sid = sid
  end

  def to_jwt
    JWT.encode(claims, key.keypair, JwtAccessToken.algorithm, typ: "logout+jwt", kid: key.kid)
  end

  private

  attr_reader :application, :subject, :sid

  def claims
    now = Time.current.to_i

    {
      iss: Issuer.url,
      aud: application.uid,
      sub: subject.to_s,
      sid: sid,
      iat: now,
      exp: now + 2.minutes.to_i,
      jti: SecureRandom.uuid,
      events: { EVENT => {} }
    }
  end

  def key = JwtAccessToken.signing_key
end
