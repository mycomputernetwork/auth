# Working in this repo

`auth` is the OIDC provider for the mycomputer.network fleet — the only
service that talks to Google, and the only place an allowlist is enforced or
a user is revoked. Rails 8, SQLite, no Node. Deployed to `~/services/auth`
on port 3001.

## Read these first, in order

1. `docs/tracker.md` — milestone status, what to click, what is next.
2. `docs/clients.md` — the contract downstream apps integrate against.
3. [ADR 0003 in noted](https://github.com/mycomputernetwork/noted/blob/main/docs/ADR/0003-centralized-auth-service.md)
   — why this service exists and what shape it takes. Decisions live there,
   not here.

## Conventions

- Slim by intent. No admin UI, no consent screen, no user profiles, no API
  docs. Allowlisting and revocation are `bin/rails runner` operations.
- The test suite is request specs only, covering the protocol: sign-in
  rejection paths, discovery, JWKS, the PKCE exchange, refresh rotation,
  refresh after revocation, logout token delivery. Not the views.
- Update `docs/tracker.md` at the end of every session.
- No comments that restate the code, label an obvious purpose, or narrate
  structure. Don't cite ADR section numbers in code.
- Sign in locally at `/dev/sign_in` — no Google credentials needed on a
  development machine.
