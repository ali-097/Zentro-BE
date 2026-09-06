# Zentro API

The backend for **Zentro**, an expense-sharing app — groups, shared expenses, split
calculation, running balances and settle-up.

The Angular client lives in a separate repository: **[zentro-fe](https://github.com/ali-097/zentro-fe)**.
The two are kept in sync by an OpenAPI contract; see [Cross-repo contract](#cross-repo-contract).

| | |
|---|---|
| **Stack** | NestJS 11 · TypeScript 5.7 · PostgreSQL 16 · TypeORM · Jest |
| **Node** | 22 (see `.nvmrc`) |
| **API base** | `/api/v1` |
| **Docs** | Swagger UI at `http://localhost:3000/docs` |
| **Board** | [Zentro project board](https://github.com/users/ali-097/projects) |

---

## Project status

> **Pre-release. The `M0 Foundation` milestone is in progress.**
>
> This README, `ARCHITECTURE.md` and `docs/` describe the **target** design — they are what
> M0 builds toward and what every issue is written against. Read them as the spec.
>
> Working today: `start:dev`, `lint`, `typecheck`, `test`, `build`, `docker compose up -d db`.
>
> Landing with M0: migrations (`migration:*` need `src/database/data-source.ts`), `seed`,
> `openapi:emit`, `/healthz`, and validated config. Until those land, the app still boots
> with the scaffold's settings. Each is a `priority:P0` issue on the board.

---

## Quickstart

You need **Node 22** and **Docker** (for Postgres). From a clean clone:

**Working today**, while M0 is in progress:

```bash
npm ci                       # install dependencies
cp .env.example .env         # sane local defaults, works as-is
docker compose up -d db      # start Postgres on :5432
npm run start:dev            # API on http://localhost:3000
```

`curl http://localhost:3000` returns `Hello World!` — the scaffold route. That is the whole
API surface right now.

**The full sequence, once M0 has landed**, adds three steps that do not work yet:

```bash
npm run migration:run        # create the schema        (needs #4)
npm run seed                 # demo users and expenses  (needs #15)
curl http://localhost:3000/healthz     # {"status":"ok"} (needs #12)
```

…and **http://localhost:3000/docs** for the full API surface (needs #11).

If you run those today they will fail, and that is expected — see
[Project status](#project-status) above. They are listed here so the target sequence is
obvious, not because they are ready.

If any of the above fails, the fix is almost certainly in
**[docs/runbooks/local-dev.md](./docs/runbooks/local-dev.md)** — it covers port conflicts,
migration failures and connection errors. If your problem isn't there, that's a
documentation bug worth filing.

> Prefer not to run Docker? Any local Postgres 16 works — point `DB_*` in `.env` at it and
> skip the `docker compose` step.

---

## Scripts

| Command | What it does |
|---|---|
| `npm run start:dev` | Watch-mode dev server on `:3000` |
| `npm run start:prod` | Run the compiled build (`dist/main`) |
| `npm run build` | Compile to `dist/` |
| `npm run lint` | ESLint, check only — this is what CI runs |
| `npm run lint:fix` | ESLint with `--fix` |
| `npm run format` | Prettier over `src/` and `test/` |
| `npm run typecheck` | `tsc --noEmit` — fastest correctness check |
| `npm test` | Unit tests |
| `npm run test:watch` | Unit tests in watch mode |
| `npm run test:cov` | Unit tests with a coverage report |
| `npm run test:e2e` | Integration tests (**needs a running test database**) |
| `npm run migration:generate -- src/database/migrations/<Name>` | Diff entities against the DB and write a migration |
| `npm run migration:run` | Apply pending migrations |
| `npm run migration:revert` | Roll back the most recent migration |
| `npm run seed` | Load demo data into the local database |
| `npm run openapi:emit` | Write `openapi.json` from the running Swagger document |

---

## Project layout

```
src/
  common/          Cross-cutting: guards, interceptors, filters, decorators, pipes,
                   and the money/split helpers every feature depends on
  config/          Typed, validated configuration loaded once at boot
  database/        DataSource, migrations, seeds
  modules/         One module per aggregate — auth, users, groups, expenses,
                   settlements, attachments, currencies, activity
  main.ts          Bootstrap: global pipes, filters, Swagger, security middleware
test/              Integration and e2e tests
docs/              Architecture, data model, API conventions, ADRs, runbooks
```

A full annotated tree and a "where do I put X?" table live in
[docs/structure.md](./docs/structure.md).

---

## Architecture in one paragraph

Requests enter through a **controller**, which validates input into a DTO and applies
guards. Controllers call a **service**, which holds all business logic and never sees HTTP.
Services use **repositories** for persistence. Money is stored as integer minor units,
balances are computed as SQL aggregates rather than in application memory, and every
group-scoped route is authorized against group membership.

Read [ARCHITECTURE.md](./ARCHITECTURE.md) for the full picture, and
[docs/data-model.md](./docs/data-model.md) for the tables and the invariants that hold
them together — those invariants are load-bearing and not obvious from the code.

---

## Cross-repo contract

Because the client is a separate repo, **the OpenAPI document is the contract between them**:

1. This repo serves Swagger at `/docs` and emits `openapi.json` at the repo root on every
   merge to `main`.
2. zentro-fe regenerates its typed API client from that file.
3. The frontend's CI fails if its generated types drift from this document.

The practical consequence: **a breaking API change is a breaking change in another repo.**
Ship additively where you can, and when you can't, open the paired frontend issue in the
same PR description. See [docs/api/README.md](./docs/api/README.md#versioning-and-breaking-changes).

---

## Contributing

Read [CONTRIBUTING.md](./CONTRIBUTING.md) — branching, Conventional Commits, the PR flow
and the review bar. Work is tracked on the shared project board; start with anything in
the **M0 Foundation** milestone.

AI coding agents should read [AGENTS.md](./AGENTS.md).

## Security

Found a vulnerability? See [SECURITY.md](./SECURITY.md) — please don't open a public issue.
