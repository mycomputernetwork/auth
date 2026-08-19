# Tracker

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
POST a signed logout token to every app holding a live token for the session,
record each attempt in `logout_deliveries`, and revoke the session's tokens so
a refresh cannot outlive the logout. Public PKCE-only native clients work
without a secret. `docs/clients.md` is the integration contract.

**M4 — golden fixtures: next.** A rake task that freezes a real access token,
ID token, JWKS and logout token into a downstream repo, so a stub issuer
cannot drift from this one unnoticed.

| Milestone | State |
|---|---|
| M1 skeleton + Google upstream | done |
| M2 Doorkeeper OIDC provider | done |
| M3 clients + back-channel logout | done |
| M4 golden fixtures for downstream apps | next |
| Deploy to `~/services/auth` | not started |

Ids are UUIDs across auth's own tables, so a `sub` can never collide with a
value a downstream app guessed or seeded. Doorkeeper's own tables keep the
integer keys the gem ships with; only `resource_owner_id` is a string.

## Unexercised

- The revoked and non-allowlisted paths against *Google* rather than the dev
  picker. The happy path has been walked with real credentials.
- Deployment. No Capistrano config, no Pangolin resource, no launchd label.
- A real downstream app. Logout deliveries are asserted against stubbed HTTP;
  nothing has yet verified an auth-issued token or consumed a logout token.
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
9. After that, sign out and check `LogoutDelivery.last` — with no app running
   at :3000 it records `failed`, and the sign-out still completes.

## Operations

```ruby
AllowedEmail.create!(email: "someone@example.com")   # grant
User.find_by(email: "someone@example.com").revoke!   # revoke, kills sessions
```

`bin/rails db:seed` registers the `noted-development` client with a fixed uid
and secret, so a fresh clone of either repo works without sharing a database.
Registering a real client, and everything a downstream app needs to integrate,
is in [`docs/clients.md`](clients.md).
