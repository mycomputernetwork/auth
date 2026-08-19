threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Production is reached only through newt (Pangolin's local client), which
# proxies over loopback. Binding to 127.0.0.1 keeps the tailnet and the LAN
# from reaching auth directly and around Pangolin. `bind` and `port` both set
# the listener, so only one may be used.
if ENV["RAILS_ENV"] == "production"
  bind "tcp://127.0.0.1:#{ENV.fetch("PORT", 3001)}"
  bind "tcp://[::1]:#{ENV.fetch("PORT", 3001)}"
else
  port ENV.fetch("PORT", 3000)
end

workers 0

plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
