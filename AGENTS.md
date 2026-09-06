# Zentro API — Agent Instructions

For any AI coding agent (Claude Code, Cursor, Copilot, Codex). Humans: read
[CONTRIBUTING.md](./CONTRIBUTING.md).

**This file is loaded into every session — keep it short.** Details belong in `docs/`; this
file only points at them.

## What this is

Zentro is an expense-sharing app (Splitwise-class). This repo is the **REST API**; the
Angular client is a separate repo, [Zentro-FE](https://github.com/ali-097/Zentro-FE).

NestJS 11 · TypeScript · PostgreSQL · TypeORM with migrations · Jest · Node 22.

## Rules that cause real bugs when broken

1. **Money is `bigint` minor units + an ISO-4217 code.** Never a float, never `number` for an
   amount. `12.30 EUR` is `1230` + `'EUR'`. All arithmetic goes through `src/common/money/` —
   never divide an amount elsewhere.
2. **Group-scoped routes need a guard *and* a membership-scoped query.** Both, not either.
   Non-members get **404**, not 403 (403 confirms the resource exists). This is the app's
   biggest risk.
3. **`synchronize` stays `false`.** Schema changes go through a reviewed migration.
4. **Never return an entity from a controller.** Map to a response DTO — entities carry
   `password_hash`, `token_hash`, `deleted_at`.
5. **Every request DTO property needs a `class-validator` decorator.** Undecorated properties
   are rejected by `forbidNonWhitelisted` and read as a mystery 400.
6. **Splits sum exactly**: `Σ splits === expense total`. Remainder pennies use the shared
   largest-remainder helper — do not reimplement.
7. **Balances are SQL aggregates**, never summed in JavaScript.
8. **Ledger queries filter `deleted_at IS NULL`.** Forgetting this is the top cause of a
   wrong balance.

## Layering

`Controller → Service → Repository`, one direction only.

- Controllers: HTTP only. No business logic, no repository injection.
- Services: all business logic, HTTP-blind. No `Request`, no `HttpException` — throw domain
  errors from `common/errors/`. What a service needs arrives as an argument.
- One module per aggregate in `src/modules/`; cross-cutting code in `src/common/`.

## Commands

```bash
npm run start:dev     # watch mode (needs Postgres: docker compose up -d db)
npm run lint          # check only, as CI runs it; lint:fix to autofix
npm run typecheck     # fastest correctness check
npm test              # unit;  npm run test:e2e for integration (needs a database)
npm run migration:generate -- src/database/migrations/<Name>
npm run migration:run     #  ... :revert  :show
```

Before finishing: `npm run lint && npm run typecheck && npm test` pass, schema changes have a
migration whose `down()` you actually ran, and new routes have a DTO, a guard, Swagger
annotations and a test.

## Where to look

| For | Read |
|---|---|
| Tables, columns, **invariants** — before any ledger work | [docs/data-model.md](./docs/data-model.md) |
| System design, request lifecycle | [ARCHITECTURE.md](./ARCHITECTURE.md) |
| Status codes, error shape, pagination | [docs/api/README.md](./docs/api/README.md) |
| Auth, tokens, authorization rules | [docs/security.md](./docs/security.md) |
| Migrations | [docs/database.md](./docs/database.md) |
| Naming, errors, queries | [docs/conventions.md](./docs/conventions.md) |
| Test levels and what's mandatory | [docs/testing.md](./docs/testing.md) |
| Where a new file goes | [docs/structure.md](./docs/structure.md) |
| Setup problems, troubleshooting | [docs/runbooks/local-dev.md](./docs/runbooks/local-dev.md) |
| Why something is the way it is | [docs/adr/](./docs/adr/) |

Read the one you need, not all of them.
