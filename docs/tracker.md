# Tracker

_Last handoff: 11 Sep 2026._

## Status

Every milestone is built, and auth is deployed and in daily use. What each one
delivers, and the shape of the tokens, is [`docs/clients.md`](clients.md);
running it day to day is [`docs/handbook.md`](handbook.md).

| Milestone | State |
|---|---|
| M1 skeleton + Google upstream | done |
| M2 Doorkeeper OIDC provider | done |
| M3 clients + back-channel logout | done |
| M4 golden fixtures for downstream apps | done |
| M5 RP-initiated logout | done |
| Deploy to `~/services/auth` | done |

Ids are UUIDs across auth's own tables, so a `sub` can never collide with a
value a downstream app guessed or seeded. Doorkeeper's own tables keep the
integer keys the gem ships with; only `resource_owner_id` is a string.

## Production

Served at `https://auth.apps.prabhanshugupta.com` through Pangolin, from Puma on
loopback `3001` on dabba. Capistrano mirrors noted's setup one port over:
launchd label `com.auth.app`, `AUTH_DB_PATH` into `database.yml`,
`cap production auth:restart`.

`SSL_CERT_FILE=/etc/ssl/cert.pem` is in the plist and `default_env`, and has to
be: mise's Ruby is linked against a Homebrew OpenSSL whose `cert.pem` is not on
that machine, leaving it no CA store, and Google's token exchange fails to
verify. Suspect this first if a Google callback fails on the server but the same
code works locally.

Seeded by hand in production: the allowlist entry, and noted's client with
`post_logout_redirect_uri` `https://noted.apps.prabhanshugupta.com/sign_in`.

**`idp=google` skips auth's sign-in page.** An unauthenticated visitor whose
client names Google is redirected there, no page rendered in between. Starting a
flow is a GET (`allowed_request_methods = [:get]`, request validation off); the
callback still verifies `state`, so a forged start cannot become a session.
Development ignores the hint so the dev picker stays reachable.

**Passwords sit beside Google**, added 21 Aug. `POST /sign_in` with an email and
password, `has_secure_password` over `users.password_digest`, refused unless the
address is allowlisted and the account is not revoked. Same account either way —
email is the key — so a person can hold both. There is no reset flow and no
sign-up: auth cannot send email, so `auth:set_password` is an administrator
handing out a generated password, documented in the handbook.

**An issued password is one-time.** `auth:set_password` leaves
`password_changed_at` nil, and `require_own_password` holds anyone in that state
on `/password` — it is a `before_action` on `ApplicationController`, so it covers
Doorkeeper's own controllers too and an interrupted `/oauth/authorize` resumes
after they pick one. Sign-out and the end-session endpoint skip it, because
leaving must never be blocked; the token endpoint is metal and never had it.

**Signing in rotates the Rails session**, carrying `return_to` across by hand.
That hand-off is the whole reason an interrupted `/oauth/authorize` still
resumes, and `oidc_spec` holds it down — drop the carry and that spec fails.

**A failed password attempt re-renders `/sign_in` with 422**, keeping the
address they typed and focusing the password field, rather than redirecting to
an empty form. Autofilled sign-in and password fields keep the dark theme rather
than taking the browser's autofill background.

**Rate limiting is `rack-attack`**, per-process `MemoryStore`. Sign-in, the
Google callback and `/oauth/authorize` by address; the token endpoint by
`client_id`, so one client's flood cannot lock out another. Discovery, the JWKS
and `/up` are never throttled — a throttled address must still be able to verify
a token. Over the limit is 429 with `retry-after`.

## Unexercised, and known limits

- The revoked and non-allowlisted paths have only been walked against the dev
  picker, not a real Google account.
- A Google address moving onto an address auth already holds as a separate user
  is a 500, not a refusal: the lookup matches on `google_sub` and then overwrites
  `email` into the unique index. Needs two rows and a rename to reach.
- Unverified Google addresses are refused, but only because the strategy nils
  `info.email` unless Google says verified — `spec/requests/sign_in_spec.rb`
  holds that down. Never read `info.unverified_email`.
- Nothing bounds wrong password guesses per account — only the 20-a-minute
  `/sign_in` throttle per address, which many addresses get around. A per-account
  throttle is the next thing to add here.
- Nothing expires a password once chosen, and a leaked one is only replaceable by
  an administrator issuing another.
- Delivery is synchronous and unretried: a slow app blocks the logout request
  for up to 5 seconds, and a failed delivery is recorded but never retried.
- The issuer is fixed per environment while Doorkeeper derives endpoint URLs
  from the request, so running on a port other than 3001 in development produces
  a discovery document that disagrees with itself.
- Redirect URIs are registered for both `http://localhost:3001` and
  `https://auth.apps.prabhanshugupta.com`.

Run `bin/rails db:seed` after pulling: the dev client needs its
`post_logout_redirect_uri` (`http://localhost:3000/sign_in`), and without it a
local sign-out stops on auth's own page instead of returning to noted.

## Click-through

Run `bin/rails server -p 3001`, then:

1. `/` redirects to `/sign_in`.
2. `/sign_in` → "Development sign-in" → pick **Family Member**. Lands on `/`
   showing the name and email.
3. Sign out. Back at `/sign_in`, and `/` redirects there again.
4. `/dev/sign_in` → **Not Invited** → refused, "Not on the allowlist."
5. `/dev/sign_in` → **Revoked Member** → refused, "Access revoked."
6. `/dev/sign_in` returns 404 with `RAILS_ENV=production`.
6b. `bin/rails "auth:set_password[dev1@example.com]"`, then sign in with that
   email and the printed password on `/sign_in`. A wrong password is refused
   with "That email and password did not match.", keeping the address typed.
6c. That sign-in lands on `/password` and `/` will not open until a new password
   is saved; the old one no longer signs in, and `/password` is reachable again
   afterwards for a voluntary change.
7. `/.well-known/openid-configuration` and `/oauth/discovery/keys` both
   return JSON; the JWKS carries only `kty/use/alg/kid/n/e`.
8. Signed out, hitting `/oauth/authorize?client_id=noted-development&…`
   redirects to `/sign_in`, which offers Google and the dev picker — including
   when the request carries `idp=google`, which only skips the page in
   production. Picking a user redirects back to the client's `redirect_uri`
   with a `code`.
9. `/oauth/logout?client_id=noted-development&post_logout_redirect_uri=http://localhost:3000/sign_in`
   ends the session and returns to noted; the same URL with any other
   `post_logout_redirect_uri` lands on auth's own `/sign_in` instead.
10. After that, sign out and check `LogoutDelivery.order(:created_at).last` — with no app running
   at :3000 it records `failed`, and the sign-out still completes.

## Operations

Day-to-day administration — allowing, revoking, inspecting sessions, reading a
failed logout — is [`docs/handbook.md`](handbook.md).

```ruby
AllowedEmail.create!(email: "someone@example.com")   # grant
User.find_by(email: "someone@example.com").revoke!   # revoke, kills sessions
```

`bin/rails db:seed` registers the `noted-development` client with a fixed uid
and secret, so a fresh clone of either repo works without sharing a database.
Registering a real client, and everything a downstream app needs to integrate,
is in [`docs/clients.md`](clients.md).
