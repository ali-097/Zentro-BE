# ADR-0001: Keep TypeORM, replace `synchronize` with migrations

- **Status:** Accepted
- **Date:** 2026-09-06

## Context

The project was scaffolded with TypeORM and `synchronize: true`, and no entities had been
written yet — so the cost of switching ORMs was effectively zero and the choice was worth
making deliberately rather than by inheritance.

`synchronize: true` is the urgent problem regardless of ORM. It diffs entities against the
live database and alters it to match on every boot: it **drops columns** to reconcile a
rename, it produces no reviewable diff, it has no rollback, and two engineers on different
branches fight over one database. It is a prototyping convenience that becomes an incident
as soon as a second person or a deployed environment exists.

## Decision

**Keep TypeORM. Set `synchronize: false` permanently and adopt an explicit migration
workflow** (`migration:generate` / `run` / `revert`), with a dedicated `DataSource` for the
CLI and migrations committed under `src/database/migrations/`.

CI enforces this: all migrations run against an empty database, and a drift check fails the
build if the entities would generate a further diff.

## Consequences

**Good**
- Schema changes are reviewable diffs, versioned alongside the code that needs them.
- Rollback exists.
- Idiomatic NestJS — `@nestjs/typeorm` is first-party, so engineers find matching docs.
- Query Builder handles the balance and debt-simplification aggregates without dropping to
  raw SQL, which is the hardest requirement in this codebase.
- Zero migration cost: no entities existed.

**Bad**
- Roughly ninety seconds of ceremony per schema change.
- TypeORM's generator is a diffing tool, not a DBA — generated migrations must be read, not
  trusted. Renames in particular arrive as `DROP` + `ADD`. Hence the review checklist in
  [database.md](../database.md).
- TypeORM's typings are weaker than Prisma's or Drizzle's; some queries need care to stay
  type-safe.

**Neutral**
- Migration files accumulate. Fine — they're append-only and rarely read.

## Alternatives considered

**Prisma.** Better DX by a distance: one schema file, a fully-typed client, excellent
migration tooling. Rejected because it sits awkwardly inside NestJS dependency injection
(it isn't a repository, so the service/repository boundary blurs), and because the balance
and settle-up queries are aggregate-heavy — exactly where Prisma pushes you into
`$queryRaw` and loses the type safety that was the reason to adopt it.

**Drizzle.** SQL-first and the best fit for the aggregate queries, with a very light
runtime. Rejected on team cost: smallest ecosystem of the three, least familiar to most
engineers, and the fewest existing NestJS patterns to copy. For a small team where onboarding
speed matters more than query ergonomics, that outweighs the technical edge.

**Keep `synchronize: true` for now.** Rejected. It is the specific thing that destroys data.

## When to revisit

If aggregate queries end up mostly hand-written SQL anyway, Drizzle's advantage becomes real
and TypeORM's abstraction stops paying for itself.
