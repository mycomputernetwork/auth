require "ipaddr"

class BackchannelLogout
  TIMEOUT = 5

  def self.call(session) = new(session).call

  def initialize(session)
    @sid = session.sid
    @subject = session.user_id
  end

  def call
    applications.each { |application| deliver(application) }
    revoke_tokens
  end

  private

  attr_reader :sid, :subject

  def applications
    Doorkeeper::Application
      .where.not(backchannel_logout_uri: nil)
      .where(id: live_tokens.select(:application_id))
      .distinct
  end

  def live_tokens = Doorkeeper::AccessToken.where(sid: sid, revoked_at: nil)

  def deliver(application)
    token = LogoutToken.new(application: application, subject: subject, sid: sid).to_jwt
    response = post(application.backchannel_logout_uri, token)

    record(application, response.is_a?(Net::HTTPSuccess) ? "delivered" : "rejected", "HTTP #{response.code}")
  rescue StandardError => e
    record(application, "failed", e.message.truncate(200))
  end

  def post(uri, token)
    uri = URI(uri)
    raise "untrusted logout URI" unless deliverable?(uri)

    request = Net::HTTP::Post.new(uri)
    request.set_form_data(logout_token: token)

    Net::HTTP.start(uri.host, uri.port,
                    use_ssl: uri.scheme == "https",
                    open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.request(request)
    end
  end

  def deliverable?(uri)
    return false unless uri.is_a?(URI::HTTP)

    host = uri.host.to_s.downcase
    return false if host.empty? || host == "localhost" || host.end_with?(".local", ".localhost")

    address = IPAddr.new(host)
    !(address.loopback? || address.private? || address.link_local? || address.multicast?)
  rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
    true
  end

  def record(application, status, detail)
    LogoutDelivery.create!(application: application, sid: sid, status: status, detail: detail)
  end

  def revoke_tokens
    live_tokens.update_all(revoked_at: Time.current)
    Doorkeeper::AccessGrant.where(sid: sid, revoked_at: nil).update_all(revoked_at: Time.current)
  end
end
