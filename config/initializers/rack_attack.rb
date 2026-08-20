Rack::Attack.enabled = !Rails.env.test?

# Puma runs single-process here, so per-process counters are the whole picture
# and cost no database writes on the request path.
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

# Relying parties fetch these unauthenticated on boot and on cache expiry.
Rack::Attack.safelist("discovery and health") do |req|
  req.get? && [
    "/up",
    "/.well-known/openid-configuration",
    "/oauth/discovery/keys"
  ].include?(req.path)
end

Rack::Attack.throttle("sign-in by ip", limit: 20, period: 1.minute) do |req|
  req.ip if req.path == "/sign_in" || req.path.start_with?("/auth/")
end

Rack::Attack.throttle("authorize by ip", limit: 30, period: 1.minute) do |req|
  req.ip if req.path.start_with?("/oauth/authorize")
end

# A wrong client secret is the one guessable credential auth has, so the token
# endpoint is bounded per client as well as per address.
Rack::Attack.throttle("token by client", limit: 60, period: 1.minute) do |req|
  if req.post? && req.path == "/oauth/token"
    req.params["client_id"].presence || req.get_header("HTTP_AUTHORIZATION").presence || req.ip
  end
end

Rack::Attack.throttle("requests by ip", limit: 300, period: 1.minute, &:ip)

Rack::Attack.throttled_responder = lambda do |request|
  retry_after = (request.env["rack.attack.match_data"] || {})[:period].to_i
  [ 429, { "content-type" => "text/plain", "retry-after" => retry_after.to_s }, [ "Too many requests\n" ] ]
end

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  request = payload[:request]
  Rails.logger.warn("[rack-attack] #{request.env['rack.attack.matched']} #{request.ip} #{request.request_method} #{request.fullpath}")
end
