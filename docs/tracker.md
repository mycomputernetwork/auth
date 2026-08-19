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

**M3 — clients and back-channel logout: next.** The
`backchannel_logout_uri` column and the `sid` columns already exist; what is
missing is `/logout` fanning out signed logout tokens and recording the
deliveries.

| Milestone | State |
|---|---|
| M1 skeleton + Google upstream | done |
| M2 Doorkeeper OIDC provider | done |
| M3 clients + back-channel logout | next |
| M4 golden fixtures for downstream apps | not started |
| Deploy to `~/services/auth` | not started |

## Unexercised

- The real Google callback. Specs use OmniAuth's test mode; no credentials
  exist yet, so `omniauth-google-oauth2` has never made a round-trip.
- Deployment. No Capistrano config, no Pangolin resource, no launchd label.
- Public (secret-less) native clients. The schema allows them; none exist.
- The issuer is fixed per environment while Doorkeeper derives endpoint URLs
  from the request, so running on a port other than 3001 in development
  produces a discovery document that disagrees with itself.

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
   redirects to `/dev/sign_in`; after picking a user it redirects back to the
   client's `redirect_uri` with a `code`.

## Operations

```ruby
AllowedEmail.create!(email: "someone@example.com")   # grant
User.find_by(email: "someone@example.com").revoke!   # revoke, kills sessions
```

`bin/rails db:seed` registers the `noted-development` client with a fixed uid
and secret, so a fresh clone of either repo works without sharing a database.
