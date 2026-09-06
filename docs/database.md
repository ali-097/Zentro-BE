# Database & migrations

PostgreSQL 16 via TypeORM. **`synchronize` is `false` and stays `false`** — every schema
change goes through a migration. See [ADR-0001](./adr/0001-typeorm-with-migrations.md).

## Why not `synchronize: true`

It was `true` when this project started, which is why it's called out here. `synchronize`
diffs your entities against the live database and alters it to match, on every boot. It is
fine for a solo prototype and dangerous the moment anyone else is involved:

- It **drops columns** to match entities. Renaming a property silently deletes the old column
  and its data.
- There is no review step. Schema changes never appear in a diff, so nobody reviews them.
- There is no rollback, and no record of what changed when.
- Two engineers with different branches fight over the same database.

Migrations cost about ninety seconds per schema change and remove that entire category of
incident.

## Everyday workflow

```bash
# 1. Change or add an entity
# 2. Generate a migration from the diff
npm run migration:generate -- src/database/migrations/AddExpenseCategory

# 3. READ IT. Generated SQL is a starting point, not an answer.
# 4. Apply it
npm run migration:run

# 5. Verify it reverses cleanly
npm run migration:revert && npm run migration:run
```

Step 5 is not optional. A `down()` that doesn't work is discovered during an incident,
which is the worst possible time.

```bash
npm run migration:show      # what's applied, what's pending
npm run migration:create -- src/database/migrations/BackfillFxRates   # empty, hand-written
```

Use `create` (not `generate`) for data backfills and anything the entity diff can't see.

## Reviewing a generated migration

TypeORM's generator is a diffing tool, not a DBA. Check every time:

- [ ] **Is it dropping anything?** A rename appears as `DROP COLUMN` + `ADD COLUMN` — which
      destroys the data. Rewrite it as `ALTER TABLE ... RENAME COLUMN`.
- [ ] **Does `down()` actually reverse `up()`?** The generator often emits an incomplete one.
- [ ] **Are new foreign keys indexed?** Postgres does *not* index FKs automatically, and an
      unindexed FK makes every join and cascade slow.
- [ ] **Is a new `NOT NULL` column safe?** On a non-empty table it needs a default or a
      three-step add → backfill → constrain.
- [ ] **Does existing data need backfilling?** The generator has no idea.
- [ ] **Will it lock the table?** Adding an index on a large table wants `CONCURRENTLY`
      (which cannot run inside a transaction — the migration must be marked accordingly).

## Rules

1. **Never edit a migration that has been merged to `main`.** Someone has run it. Write a new
   one that corrects it. Editing history means two databases silently diverge.
2. **One logical change per migration.** Easier to review, easier to revert.
3. **Migrations are append-only and ordered by timestamp.** If two branches add migrations
   and merge out of order, regenerate rather than renumber by hand.
4. **Always write `down()`.** If a change is genuinely irreversible (a destructive backfill),
   say so in a comment and explain the recovery path.
5. **Never reference a TypeScript entity from a migration.** Entities change; the migration
   must keep meaning the same thing forever. Write raw SQL.
6. **Every migration runs in CI against an empty database** before it can merge, plus a drift
   check that fails if entities would generate a further diff.

## Naming

`<timestamp>-<PascalCaseDescription>.ts`, generated automatically. Describe the change, not
the ticket: `AddExpenseCategory`, not `Fix42`.

## Indexes

Add them with the migration that creates the need, not later:

- Every foreign key.
- Every column in a `WHERE` on a hot path — `group_members(user_id, left_at)` backs the
  membership guard and runs on nearly every request.
- Composite indexes for sort + filter pairs: `expenses(group_id, paid_at DESC)`.
- Partial indexes where soft deletes dominate: `WHERE deleted_at IS NULL`.

## Seeds

```bash
npm run seed          # demo users, a group, expenses across split types and currencies
npm run seed:reset    # drop, migrate, seed
```

Seeds are **development only** and must be idempotent. They are not fixtures — tests build
their own data (see [testing.md](./testing.md)).

## Resetting a local database

Safe to do freely; local data is disposable.

```bash
docker compose down -v      # -v drops the volume, i.e. all data
docker compose up -d db
npm run migration:run
npm run seed
```

## Connections and transactions

- The pool is sized by config, not left at the driver default. Free-tier Postgres allows very
  few connections — exceeding it fails at the worst moment, under load.
- **Any operation writing more than one table runs in a transaction.** Creating an expense
  touches `expenses`, `expense_payers`, `expense_splits` and `activities`; a partial write
  leaves the ledger inconsistent and violates the split-sum invariant.
- Keep transactions short. Never make an HTTP call (FX lookup, email, object storage) inside
  one — fetch first, then open the transaction.
