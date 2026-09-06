---
name: write-migration
description: Generate, review, run and verify a TypeORM migration in the Zentro API, including the review checklist that catches destructive generated SQL. Use for any schema change or data backfill.
---

# Write a migration

`synchronize` is `false` here permanently — every schema change is a reviewed, reversible
migration. See [ADR-0001](../../../docs/adr/0001-typeorm-with-migrations.md).

## Which command

```bash
# Schema change driven by an entity edit — diffs entities against the database
npm run migration:generate -- src/database/migrations/AddExpenseCategory

# Data backfill, or anything the entity diff cannot see — creates an empty file
npm run migration:create -- src/database/migrations/BackfillFxRates
```

Name it for the change, not the ticket: `AddExpenseCategory`, not `Fix42`.

## The review checklist

Generated SQL is a **draft**. Every item here has a real failure mode:

- [ ] **Is it dropping a column?** A rename generates `DROP` + `ADD`, silently destroying the
      data. Rewrite as `ALTER TABLE ... RENAME COLUMN`.
- [ ] **Does `down()` reverse `up()`?** Frequently incomplete. If a change is genuinely
      irreversible, say so in a comment and document the recovery path.
- [ ] **Are new foreign keys indexed?** Postgres does not do this for you.
- [ ] **Is a new `NOT NULL` column safe?** On a populated table it needs a default, or
      add → backfill → constrain as three steps.
- [ ] **Does data need backfilling?** The generator has no idea what your new column means.
- [ ] **Will it lock the table?** A large-table index wants `CREATE INDEX CONCURRENTLY`,
      which cannot run inside a transaction — mark the migration accordingly.
- [ ] **One logical change?** Easier to review, easier to revert.
- [ ] **Raw SQL only?** Never import an entity into a migration. Entities change; the
      migration must keep meaning the same thing forever.

## Verify the reversal

```bash
npm run migration:run
npm run migration:revert     # must succeed and leave the schema as it was
npm run migration:run
npm run migration:show       # confirm the expected state
```

Skipping the revert means discovering a broken `down()` during an incident.

## If it goes wrong locally

Local data is disposable — reset rather than hand-patching schema, which puts your database
in a state no migration describes:

```bash
docker compose down -v && docker compose up -d db
npm run migration:run && npm run seed
```

## Hard rules

1. **Never edit a merged migration.** Someone has run it. Write a corrective one.
2. **Migrations are append-only**, ordered by timestamp. If two branches merge out of order,
   regenerate — do not renumber by hand.
3. **Always write `down()`.**

## Then

- Update [docs/data-model.md](../../../docs/data-model.md) if tables, columns or invariants
  changed.
- Note in your PR whether the migration is destructive or needs a backfill window.

CI runs every migration against an empty database and fails on schema drift, so a forgotten
migration is caught before merge.
