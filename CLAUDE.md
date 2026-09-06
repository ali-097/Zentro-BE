# CLAUDE.md

@AGENTS.md

Everything below is Claude Code specific; the import above is the shared ruleset.

## Skills

Invoke rather than scaffolding by hand — each encodes the conventions in `docs/`, and loads
only when called:

- `/add-endpoint` — a new route: controller, service, DTOs, guard, Swagger, tests
- `/add-entity` — a new table: entity, relations, indexes, migration
- `/write-migration` — any schema change, with the review checklist
- `/api-review` — audit your diff before opening a PR

## Working here

- **Read `docs/data-model.md` before any ledger work.** Its invariants are load-bearing and
  invisible from the code.
- `npm run typecheck` beats a full build for checking your work.
- The dev database is disposable — reset it rather than hand-patching schema.
- `test:e2e` failing to connect means Postgres isn't up. Check `docker compose ps` first.
