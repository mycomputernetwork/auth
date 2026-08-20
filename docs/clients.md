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
| `post_logout_redirect_uri` | `BASE/sign_in` |

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
- `/oauth/logout` — RP-initiated logout, for the browser.

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

## Skipping auth's sign-in page

Add `idp=google` to the authorization request and an unauthenticated visitor is
redirected to Google rather than to auth's own page:

```
/oauth/authorize?…&idp=google  →  /auth/google_oauth2  →  accounts.google.com
```

Ordinary redirects, no page rendered in between. Any other value, or none, lands
on `/sign_in` as before. Development ignores the hint and keeps the picker,
which is the only way to sign in on a machine with no Google credentials.

Starting a sign-in is a GET, so a link on another site can begin this flow. It
cannot finish one: the callback checks `state` against auth's session, so a
forged start produces a Google screen and nothing more.

## Rate limits

The token endpoint allows 60 requests a minute per `client_id`; sign-in and
`/oauth/authorize` are limited per address. Over the limit auth answers `429`
with `retry-after` in seconds — retry after it elapses rather than immediately,
and treat it as distinct from `invalid_grant`, which will not become valid on a
retry. Discovery and the JWKS are never throttled, so verifying a token cannot
be rate-limited out of working.

## Back-channel logout

When a user signs out of auth — or is revoked — auth POSTs, server to server,
to every registered app that has ever held a token for that session. Delivery
does not depend on that token still being live: your own session can outlast the
15-minute access token, so a logout arriving later still reaches you.


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

## RP-initiated logout

Signing out of your app must end auth's session too, or the next sign-in is
silent and a shared machine keeps the account. Instead of destroying your own
session and stopping there, destroy it and redirect the browser to:

```
GET /oauth/logout
  ?id_token_hint=<the ID token from sign-in>
  &post_logout_redirect_uri=BASE/sign_in
  &state=<optional, handed back untouched>
```

Auth ends its own session, fans back-channel logouts out to the other apps,
and redirects to `post_logout_redirect_uri` — but only if that exact string is
the one registered for the client. Anything else lands on auth's sign-in page.

The hint identifies the client and the session to end. It may be expired; it
may not be forged, and one naming a session other than the browser's current
auth session redirects without signing anyone out. `client_id=<uid>` is
accepted in its place if you have not kept the ID token.

## Allowlist and revocation

Both live only in auth:

```ruby
AllowedEmail.create!(email: "someone@example.com")   # grant
User.find_by(email: "someone@example.com").revoke!   # revoke fleet-wide
```

`revoke!` fans back-channel logouts out to every app first, then drops the
sessions. Downstream apps need no user-management surface of their own.
