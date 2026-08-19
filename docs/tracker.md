# Tracker

## Status

**M1 — skeleton and the Google upstream: done.** Users, sessions, and a
table-backed allowlist exist. The OmniAuth callback finds or creates a user,
turns away anything not allowlisted or revoked, and mints a server-side
session row. A development picker stands in for Google locally.

**M2 — the OIDC provider: next.**

| Milestone | State |
|---|---|
| M1 skeleton + Google upstream | done |
| M2 Doorkeeper OIDC provider | next |
| M3 clients + back-channel logout | not started |
| M4 golden fixtures for downstream apps | not started |
| Deploy to `~/services/auth` | not started |

## Unexercised

- The real Google callback. Specs use OmniAuth's test mode; no credentials
  exist yet, so `omniauth-google-oauth2` has never made a round-trip.
- Deployment. No Capistrano config, no Pangolin resource, no launchd label.

## Click-through

Run `bin/rails server -p 3001`, then:

1. `/` redirects to `/sign_in`.
2. `/sign_in` → "Development sign-in" → pick **Family Member**. Lands on `/`
   showing the name and email.
3. Sign out. Back at `/sign_in`, and `/` redirects there again.
4. `/dev/sign_in` → **Not Invited** → refused, "Not on the allowlist."
5. `/dev/sign_in` → **Revoked Member** → refused, "Access revoked."
6. `/dev/sign_in` returns 404 with `RAILS_ENV=production`.

## Operations

```ruby
AllowedEmail.create!(email: "someone@example.com")   # grant
User.find_by(email: "someone@example.com").revoke!   # revoke, kills sessions
```
