# Runbook — local development

From nothing to a running API, plus fixes for everything that commonly goes wrong.

## Prerequisites

| | Version | Check |
|---|---|---|
| Node | 22 (see `.nvmrc`) | `node --version` |
| npm | 10+ | `npm --version` |
| Docker | any recent | `docker --version` |
| Git | any recent | `git --version` |

With `nvm`: `nvm use` picks up `.nvmrc` automatically.

Docker is only used to run Postgres. Any local Postgres 16 works instead — point `DB_*` at
it and skip the compose steps.

## First run

```bash
git clone https://github.com/ali-097/zentro-be.git
cd zentro-be

npm ci                       # ci, not install — respects the lockfile exactly
cp .env.example .env         # defaults work as-is for local development
docker compose up -d db      # Postgres on :5432
npm run migration:run        # create the schema
npm run seed                 # optional demo data
npm run start:dev            # http://localhost:3000
```

Confirm it's alive:

```bash
curl http://localhost:3000/healthz     # {"status":"ok"}
curl http://localhost:3000/readyz      # {"status":"ok","database":"up"}
```

Then open **http://localhost:3000/docs**.

Seeded accounts (development only, password `Password123!`):
`alice@zentro.test`, `bob@zentro.test`, `carol@zentro.test` — all members of a demo group
with expenses across every split type and two currencies.

## Everyday commands

```bash
npm run start:dev            # watch mode
npm run lint                 # eslint, check only; lint:fix to autofix
npm run typecheck            # fastest correctness check — use this, not a full build
npm test                     # unit tests
npm run test:e2e             # integration tests (needs the database up)

docker compose up -d db      # start Postgres
docker compose down          # stop, keep data
docker compose down -v       # stop and DELETE all local data
docker compose logs -f db    # tail Postgres logs
```

## Working with the frontend

Run [zentro-fe](https://github.com/ali-097/zentro-fe) on `:4200`; it's preconfigured to call
`http://localhost:3000/api/v1`. This origin is already in the CORS allowlist in
`.env.example`.

After changing any API shape, regenerate the frontend's client:

```bash
npm run openapi:emit                 # here — writes openapi.json
# then, in zentro-fe:
npm run api:sync
```

Skipping this is why the frontend's types stop matching reality.

---

## Troubleshooting

### `EADDRINUSE: address already in use :::3000`

Something else holds the port.

```bash
# Windows
netstat -ano | findstr :3000
taskkill /PID <pid> /F

# macOS / Linux
lsof -ti:3000 | xargs kill -9
```

Or set `PORT=3001` in `.env`.

### `ECONNREFUSED 127.0.0.1:5432`

Postgres isn't running, or isn't ready yet.

```bash
docker compose ps            # is the db container up and healthy?
docker compose up -d db
docker compose logs db
```

If the container is `unhealthy`, port 5432 is likely taken by a *local* Postgres
installation. Either stop that service, or change the published port in
`docker-compose.yml` and `DB_PORT` in `.env` to match.

### `password authentication failed for user`

The volume was created with different credentials than the ones now in `.env` — Postgres
only reads `POSTGRES_USER`/`POSTGRES_PASSWORD` when it *first* initializes the data
directory. Changing `.env` afterwards has no effect.

```bash
docker compose down -v       # deletes local data — fine, it's disposable
docker compose up -d db
npm run migration:run && npm run seed
```

### `Config validation error: "JWT_SECRET" is required`

Working as intended — the app refuses to boot with missing or invalid configuration rather
than falling back to an insecure default. Copy the missing key from `.env.example`.

### `QueryFailedError: relation "..." does not exist`

Migrations haven't run against this database.

```bash
npm run migration:run
npm run migration:show       # confirm what's applied
```

### A migration failed halfway

Local data is disposable. Don't hand-patch the schema:

```bash
docker compose down -v && docker compose up -d db && npm run migration:run
```

### `npm run migration:generate` produces an empty migration

The entities already match the database — usually because you ran with an old schema, or
`synchronize` was accidentally re-enabled. Verify `synchronize: false` in
`src/database/data-source.ts`. If it is `true`, that is a bug: fix it, don't work around it.

### Tests fail with connection errors

`test:e2e` needs Postgres running. `docker compose up -d db`.

### Everything is inexplicably broken

```bash
rm -rf node_modules dist && npm ci
docker compose down -v && docker compose up -d db
npm run migration:run && npm run seed
```

---

## Something not covered here?

That's a documentation bug. Once you've solved it, add it to this file in your next PR —
the next person will hit the same thing.
