# auth

The OIDC provider for the mycomputer.network fleet. One service talks to
Google; `noted`, `chat`, and the native clients trust it and verify its
tokens against a published JWKS.

Rails 8, SQLite, no Node. Runs on port 3001, served at
`auth.mycomputer.network`.

## Development

```bash
mise trust && mise install
mise run setup
mise run server
```

`mise` pins Ruby 3.4.10 and keeps gems in `vendor/bundle`, per app rather
than per machine.

Sign in at `/dev/sign_in` with a fixture from `config/dev_users.yml`. No
Google credentials are needed locally.

```bash
mise run test
```

Integrating another app: [`docs/clients.md`](docs/clients.md).
Allowing and revoking people: [`docs/operations.md`](docs/operations.md).

Design decisions live in
[ADR 0003](https://github.com/mycomputernetwork/noted/blob/main/docs/ADR/0003-centralized-auth-service.md);
current state in [`docs/tracker.md`](docs/tracker.md).
