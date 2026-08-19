# Integrating an app with auth

The contract between `auth` and everything else in the fleet. Read this from
a downstream repo; nothing here requires reading auth's source.

## Register the client

Development, in this repo:

```bash
bin/rails db:seed
```

That registers `noted-development` (secret `noted-development-secret`) and a
public client `noted-native-development`. Both uids are fixed, so a fresh
clone of either repo works without the two databases knowing about each other.

Production, on dabba:

```bash
bin/rails "auth:register_client[noted,https://noted.mycomputer.network]"
bin/rails "auth:register_native_client[noted-android,network.mycomputer.noted://oauth/callback]"
```

The first prints a uid and secret to paste into that app's credentials, and
derives two URLs the app must serve:

| | |
|---|---|
| `redirect_uri` | `BASE/auth/oidc/callback` |
| `backchannel_logout_uri` | `BASE/auth/backchannel_logout` |

The second registers a public client: no secret, because an APK or an app
bundle cannot keep one. PKCE is what replaces it, and auth requires PKCE of
every client, confidential ones included.

There is no registration UI, and no dynamic registration. Five apps, each
registered once.

## Endpoints

`GET /.well-known/openid-configuration` lists them all. The two that matter
to a resource server:

- `/oauth/discovery/keys` — JWKS. Cache it; refetch on an unknown `kid`.
- `/oauth/token` — code exchange and refresh.

The issuer is `https://auth.mycomputer.network` in production and
`http://localhost:3001` in development. Verify it: it is the `iss` claim on
every token below.

## What the tokens look like

Access token, RS256, 15 minutes:

```json
{ "iss": "…", "sub": "7", "aud": "<client uid>", "exp": …, "iat": …,
  "jti": "…", "scope": "openid email profile offline_access", "sid": "…" }
```

ID token, RS256, same `sub` and `sid`, plus `email`, `email_verified`,
`name`, `nonce`, `auth_time`.

`sub` is auth's own user id — a UUID, never Google's subject — a re-linked Google account does
not change the identity you have stored. `sid` identifies the auth session
behind the token; store it on your session row, because that is what a logout
arrives carrying.

A resource server verifies signature, `iss`, `aud` (its own uid) and `exp`
locally against the JWKS. No call to auth on the request path.

## Refresh

Refresh tokens rotate: each refresh issues a new one and revokes the previous
access token immediately. A refresh by a revoked user is rejected with
`invalid_grant`, which is what makes the 15-minute access token TTL the real
bound on revocation.

## Back-channel logout

When a user signs out of auth — or is revoked — auth POSTs, server to server,
to every registered app holding a live access token for that session:

```
POST BASE/auth/backchannel_logout
Content-Type: application/x-www-form-urlencoded

logout_token=<JWT>
```

The token is RS256 with `typ: logout+jwt` and carries `iss`, `aud`, `sub`,
`sid`, `iat`, `exp` (2 minutes), `jti`, and:

```json
"events": { "http://schemas.openid.net/event/backchannel-logout": {} }
```

An app verifies it exactly as it verifies an access token, then deletes the
session row whose `sid` matches, and returns `200`. It must reject a token
carrying a `nonce` claim, per the spec.

Every attempt is recorded in auth's `logout_deliveries`, so a logout that did
not land is visible rather than silent:

```ruby
LogoutDelivery.failed.where("created_at > ?", 1.day.ago)
```

## Allowlist and revocation

Both live only in auth:

```ruby
AllowedEmail.create!(email: "someone@example.com")   # grant
User.find_by(email: "someone@example.com").revoke!   # revoke fleet-wide
```

`revoke!` fans back-channel logouts out to every app first, then drops the
sessions. Downstream apps need no user-management surface of their own.
