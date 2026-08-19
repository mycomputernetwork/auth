# auth

The OIDC provider for the mycomputer.network fleet. One service talks to
Google; `noted`, `chat`, and the native clients trust it and verify its
tokens against a published JWKS.

Rails 8, SQLite, no Node. Runs on port 3001, served at
`auth.mycomputer.network`.

## Development

```bash
bin/setup
bin/rails server -p 3001
```

Sign in at `/dev/sign_in` with a fixture from `config/dev_users.yml`. No
Google credentials are needed locally.

```bash
bundle exec rspec
```

Design decisions live in
[ADR 0003](https://github.com/mycomputernetwork/noted/blob/main/docs/ADR/0003-centralized-auth-service.md);
current state in [`docs/tracker.md`](docs/tracker.md).
