# Working in this repo

`auth` is the OIDC provider for the mycomputer.network fleet — the only service
that talks to Google, the only place an allowlist is enforced, and the only
place a person can be revoked across every app at once. Rails 8, SQLite, no
Node. Runs on port 3001, deployed to `~/services/auth`, served at
`auth.mycomputer.network`.

## Read these first, in order

1. `docs/tracker.md` — milestone status, what to click, what is unexercised.
2. `docs/clients.md` — the contract downstream apps integrate against:
   registration, endpoints, token shapes, back-channel logout.
3. `docs/operations.md` — allowing, revoking, looking around, and what the
   common sign-in failures mean.
4. [ADR 0003 in noted](https://github.com/mycomputernetwork/noted/blob/main/docs/ADR/0003-centralized-auth-service.md)
   — why this service exists and what shape it takes. Decisions live there.

## Running it

```sh
mise run setup    # gems, database, development clients
mise run server   # :3001
mise run test     # rspec
```

Sign in locally at `/sign_in`: it offers Google and, in development only, a
picker over `config/dev_users.yml`. No Google credentials are needed to work on
anything but the Google callback itself.

## How it fits together

- **Sessions are server-side rows.** Silent SSO needs a session to find, and
  back-channel logout needs one to delete. The cookie carries only the `sid`.
- **Access tokens are RS256 JWTs**, 15 minutes, carrying `sub`, `aud`, `sid`.
  Resource servers verify them against `/oauth/discovery/keys` with no call back
  here. That short TTL is the real bound on revocation, so do not lengthen it
  without saying what replaces it.
- **`sub` is a UUID**, auth's own user id. Google's subject never leaves this
  app, and downstream apps must never be able to guess a subject — they once
  could, when ids were integers, and a real account inherited a seeded one.
- **PKCE is required of every client**, confidential ones included. Native
  clients are public and hold no secret.
- **Doorkeeper's own tables keep the gem's integer keys**; only
  `resource_owner_id` is a string. Everything auth owns uses UUIDs.

## Conventions

- Slim by intent. No admin UI, no consent screen, no user profiles, no dynamic
  client registration. Allowlisting, revocation and client registration are
  `bin/rails runner` and rake tasks — see `docs/operations.md`.
- Let libraries do the work: Doorkeeper for the protocol, omniauth for Google,
  the `jwt` gem for signing. Reach for a hand-rolled flow only when a gem's
  dependency footprint is worse than the code it saves.
- The suite is request specs covering the protocol — the rejection paths,
  discovery, JWKS, the PKCE exchange, refresh rotation, refresh after
  revocation, logout delivery. Not the two views.
- Development identities are `Dev user 1`…`Dev user 4` at `dev1@example.com`…,
  the third refused by the allowlist and the fourth revoked. Keep them neutral
  and keep the refused ones — they are the only way those paths get walked.
- Update `docs/tracker.md` at the end of every session, and `docs/clients.md`
  whenever a token claim, endpoint or registration step changes. A downstream
  app reads that file instead of this source.
- No comments that restate the code, label an obvious purpose, or narrate
  structure. Don't cite ADR section numbers in code.
