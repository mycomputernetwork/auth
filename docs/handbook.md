# Running auth

Everything you do to auth after it is deployed. There is no admin UI: these are
`bin/rails runner` and `bin/rails console` on the server, in `~/services/auth/current`.

## Letting someone in

Two lists, and while the Google consent screen is in Testing mode a person
needs to be on both.

1. **Google**, once per person: Cloud console → APIs & Services → OAuth consent
   screen → **Test users** → add their address. Skipping this means Google
   refuses before auth ever sees them (`access_denied`).
2. **auth**, once per person:

```ruby
AllowedEmail.create!(email: "someone@example.com")
```

They sign in at any app in the fleet; auth creates the account on first
callback. Nothing to do in noted or chat — an account appears there the first
time they arrive.

The allowlist is checked on **sign-in only**. Adding an address lets someone in;
removing one does not put anybody out. That is what revocation is for.

## Passwords

Google is the usual way in; a password is for people Google cannot serve. Both
land on the same account, keyed by email, and both are refused unless the
address is on the allowlist.

```bash
bin/rails "auth:set_password[someone@example.com]"
```

That prints a **one-time** password — hand it over out of band. It creates the
account if it does not exist yet, so a password-only person never needs Google.
Passing one yourself is `auth:set_password[someone@example.com,their-password]`.

The password you issue is not the password they keep. Their first sign-in lands
on `/password` and goes no further until they pick their own — not the apps, not
even an `/oauth/authorize` a client started. After that you do not know their
password, and `password_changed_at` says when they picked it. Twelve characters
minimum; they can come back to `/password` any time to change it again.

**Forgotten passwords are resets.** auth sends no email, so there is no reset
link and no self-service: the person asks, you run the same task again, and they
are handed another one-time password to replace. Setting one does not end their
live sessions — do that by hand if the old one may have leaked:

```ruby
User.find_by(email: "someone@example.com").sessions.destroy_all
```

Taking the password away, leaving only Google:

```bash
bin/rails "auth:clear_password[someone@example.com]"
```

Password attempts are throttled with the rest of `/sign_in`: 20 a minute per
address.

## Putting someone out

```ruby
User.find_by(email: "someone@example.com").revoke!
```

This is the fleet-wide switch, and it does four things: stamps `revoked_at`,
revokes their access and refresh tokens, POSTs a logout token to every app
holding a live session for them, and deletes auth's own sessions. Their web
sessions end within seconds; any access token already in a native client's hand
dies within 15 minutes, which is the whole reason the TTL is short.

Check the logouts actually landed:

```ruby
LogoutDelivery.where(created_at: 5.minutes.ago..).pluck(:status, :detail)
```

`delivered` is what you want. `rejected` means the app answered with an error;
`failed` means it could not be reached, and that app still holds a live session
until its own 30-day expiry. Deliveries are not retried — if you see `failed`,
restart the app and revoke again.

Letting them back in:

```ruby
User.find_by(email: "someone@example.com").update!(revoked_at: nil)
```

Their old tokens stay dead; they sign in again from scratch.

## Looking around

```ruby
User.pluck(:email, :revoked_at)                      # who exists, who is out
User.where.not(password_digest: nil).pluck(:email, :password_changed_at)
# a nil password_changed_at is someone still holding the password you issued
AllowedEmail.pluck(:email)                           # who may enter
Session.joins(:user).pluck("users.email", :last_seen_at, :ip_address)
Doorkeeper::Application.pluck(:name, :uid, :confidential)
Doorkeeper::AccessToken.where(revoked_at: nil).count # live tokens right now
```

Ending one person's sessions without revoking them — the "signed in on a lost
phone" case:

```ruby
User.find_by(email: "someone@example.com").sessions.each { BackchannelLogout.call(it) }
User.find_by(email: "someone@example.com").sessions.destroy_all
```

## Adding an app to the fleet

See `docs/clients.md`. Short version:

```bash
bin/rails "auth:register_client[chat,https://chat.mycomputer.network]"
```

Paste the printed uid and secret into that app's credentials. Native clients get
`auth:register_native_client` and no secret.

## When sign-in breaks

- **`redirect_uri_mismatch`** — the URI auth sent is not registered in the Google
  console. It must match exactly, no trailing slash, `http` for localhost.
- **"That account is not allowed to sign in"** — no `AllowedEmail` row. auth
  reached Google fine; this is auth's own refusal.
- **"That account's access has been revoked"** — `revoked_at` is set.
- **"That email and password did not match"** — wrong password, no password set
  on that account, or the address is not allowlisted. The message does not say
  which, on purpose; check with the queries above.
- **An app keeps redirecting to auth** — its client uid or secret no longer
  matches `oauth_applications`. Re-register it.
- **An app signs people out constantly** — its clock is off, or it is verifying
  against a stale JWKS. Both show up as `exp`/signature failures in its log.

## The signing key

The RS256 key lives in auth's encrypted credentials, so it travels with
`config/master.key` in `shared/config` on the server. Losing that key means
every downstream app's trust has to be re-established: nothing else can sign
tokens they will accept. Back it up somewhere that is not this machine.
