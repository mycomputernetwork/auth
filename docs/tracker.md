# Tracker

_Last handoff: 20 Aug 2026._

## Status

**M1 — skeleton and the Google upstream: done.** Users, sessions, and a
table-backed allowlist exist. The OmniAuth callback finds or creates a user,
turns away anything not allowlisted or revoked, and mints a server-side
session row. A development picker stands in for Google locally.

**M2 — the OIDC provider: done.** Doorkeeper with `doorkeeper-openid_connect`,
RS256 key from credentials, discovery and JWKS published. Access tokens are
RS256 JWTs (15 minutes) carrying `sid`, so resource servers verify offline.
PKCE is required, refresh tokens rotate and the old access token is revoked
on use, and a refresh by a revoked user is rejected before Doorkeeper sees it.

**M3 — clients and back-channel logout: done.** `/logout` and `User#revoke!`
POST a signed logout token to every app that ever held a token for the session,
record each attempt in `logout_deliveries`, and revoke the session's tokens so
a refresh cannot outlive the logout. Public PKCE-only native clients work
without a secret. `docs/clients.md` is the integration contract.

**M5 — RP-initiated logout: done.** `GET /oauth/logout` (advertised as
`end_session_endpoint` in discovery) ends auth's session and returns the
browser to the client. `EndSession` decodes the `id_token_hint` — signature and
`iss` checked, expiry deliberately not, since an ID token outlives its two
minutes in a browser that has been idle — and redirects only to the exact
`post_logout_redirect_uri` registered on `oauth_applications`. A hint naming
some other `sid` redirects without ending the browser's session. `client_id`
is accepted in place of a hint. Sign-out runs the usual back-channel fan-out,
so the other apps hear about it.

**M4 — golden fixtures: done.** `spec/golden_fixtures_spec.rb` (tagged `:golden`,
excluded from the suite, run deliberately) drives a real PKCE exchange with a
frozen clock and writes a real access token, ID token, JWKS and logout token to
`spec/fixtures/golden.json`. `rake auth:golden_fixtures[../noted]` copies it into a
downstream repo, where one spec verifies the tokens through the real verifier and
asserts its stub cannot drift from this one unnoticed.

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

**Deployed.** Capistrano mirrors noted's setup one port over: Puma on loopback
`3001`, launchd label `com.auth.app`, `AUTH_DB_PATH` into `database.yml`,
`cap production auth:restart`. Pangolin serves `auth.mycomputer.network` from
dabba's newt client. Production data was seeded by hand: the allowlist entry and
noted's production client, whose `post_logout_redirect_uri` is
`https://noted.mycomputer.network/sign_in`.

**`SSL_CERT_FILE=/etc/ssl/cert.pem` is required on the server.** mise's Ruby is
linked against a Homebrew OpenSSL whose `cert.pem` is not on that machine, which
leaves it with no CA store at all: Google's token exchange fails to verify the
certificate and sign-in dies after the redirect. It is in the launchd plist and
`default_env` now. Suspect this first if a Google callback fails on the server
but the same code works locally.

**Walked in production on 20 Aug.** A real Google identity signed into noted
through auth and out again via `/oauth/logout`: the back-channel fan-out
recorded `delivered`, the access token was revoked, and both session rows
disappeared. `sub` reached noted as a UUID.

**Rate limiting: `rack-attack`.** A per-process `MemoryStore`, since Puma runs a
single worker and SQLite should not take a write per request. Sign-in and the
Google callback are throttled by address; `/oauth/authorize` by address; the
token endpoint by `client_id`, because a wrong client secret is the one
guessable credential auth has, and one client's flood must not lock out
another's. Discovery, the JWKS and `/up` are safelisted outright — relying
parties fetch them unauthenticated and a throttled address must still be able
to verify a token. Throttled requests get 429 with `retry-after`.

**Sign-in pages restyled.** `app/assets/stylesheets/application.css` carries the
subset of noted's design tokens the two views need — same system font stack,
sizes, spacing and surfaces — so the two apps read as one product. No accent
colour: the screen is greyscale apart from the Google mark and the error red. Both
`/sign_in` and `/dev/sign_in` are a centred card: the hand-drawn logo
(`app/assets/images/logo.jpg`), a title, and a full-width button with the Google
mark inline as SVG.

## Unexercised

- The revoked and non-allowlisted paths against *Google* rather than the dev
  picker. The happy path has been walked with real credentials.
- Nothing outstanding in the handshake itself: noted has verified an
  auth-issued token, and a real back-channel logout was delivered end to end
  (`delivered`, HTTP 200) on 19 Aug.
- Nothing outstanding in RP-initiated logout: walked from noted's account menu
  and again by curl on 20 Aug — valid, expired, forged and foreign-`sid` hints,
  an unregistered redirect, an unknown client, `state`, and a second logout
  after the session was already gone. `bin/rails db:seed` again after pulling,
  though: the dev client needs its `post_logout_redirect_uri`
  (`http://localhost:3000/sign_in`), and without it the browser stops on auth's
  sign-in page instead of returning to noted.
- Delivery is synchronous and unretried: a slow app blocks the logout request
  for up to 5 seconds, and a failed delivery is recorded but never retried.
- The issuer is fixed per environment while Doorkeeper derives endpoint URLs
  from the request, so running on a port other than 3001 in development
  produces a discovery document that disagrees with itself.

Google's redirect URIs are registered for both `http://localhost:3001` and
`https://auth.mycomputer.network`. While the consent screen is in Testing,
a new person needs two entries: a Google test user *and* an `AllowedEmail`.

## Click-through

Run `bin/rails server -p 3001`, then:

1. `/` redirects to `/sign_in`.
2. `/sign_in` → "Development sign-in" → pick **Family Member**. Lands on `/`
   showing the name and email.
3. Sign out. Back at `/sign_in`, and `/` redirects there again.
4. `/dev/sign_in` → **Not Invited** → refused, "Not on the allowlist."
5. `/dev/sign_in` → **Revoked Member** → refused, "Access revoked."
6. `/dev/sign_in` returns 404 with `RAILS_ENV=production`.
7. `/.well-known/openid-configuration` and `/oauth/discovery/keys` both
   return JSON; the JWKS carries only `kty/use/alg/kid/n/e`.
8. Signed out, hitting `/oauth/authorize?client_id=noted-development&…`
   redirects to `/sign_in`, which offers Google and the dev picker; after picking a user it redirects back to the
   client's `redirect_uri` with a `code`.
9. `/oauth/logout?client_id=noted-development&post_logout_redirect_uri=http://localhost:3000/sign_in`
   ends the session and returns to noted; the same URL with any other
   `post_logout_redirect_uri` lands on auth's own `/sign_in` instead.
10. After that, sign out and check `LogoutDelivery.last` — with no app running
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
