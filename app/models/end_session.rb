class EndSession
  def initialize(params)
    @hint = params[:id_token_hint].presence
    @client_id = params[:client_id].presence
    @requested_uri = params[:post_logout_redirect_uri].presence
    @state = params[:state].presence
    @claims = hint && decode(hint)
  end

  # A hint naming another session is not this browser's to end: the RP asking
  # holds a token from a session that has already gone.
  def ends?(session) = claims.nil? || claims["sid"] == session.sid

  def redirect_url
    return unless requested_uri && registered?(requested_uri)
    return requested_uri unless state

    uri = URI(requested_uri)
    uri.query = [uri.query, { state: state }.to_query].compact.join("&")
    uri.to_s
  end

  private

  attr_reader :hint, :client_id, :requested_uri, :state, :claims

  def registered?(uri) = application&.post_logout_redirect_uri.to_s.split.include?(uri)

  def application
    return if hint && claims.nil?

    @application ||= Doorkeeper::Application.find_by(uid: Array(claims&.dig("aud")).first || client_id)
  end

  def decode(token)
    JWT.decode(token, JwtAccessToken.signing_key.keypair.public_key, true,
               algorithms: [JwtAccessToken.algorithm],
               iss: Issuer.url, verify_iss: true,
               verify_expiration: false).first
  rescue JWT::DecodeError
    nil
  end
end
