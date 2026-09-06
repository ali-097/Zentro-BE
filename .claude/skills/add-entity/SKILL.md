---
name: add-entity
description: Add a TypeORM entity to the Zentro API - columns, relations, indexes, constraints and the paired migration - following the money, soft-delete and authorization conventions. Use when adding a new table or changing an existing one.
---

# Add or change an entity

## 1. Read the data model first

[docs/data-model.md](../../../docs/data-model.md) documents every table and the invariants
that hold the ledger together. Check whether what you need already exists in another shape,
and check which invariants your change could break.

If your change adds or alters an invariant, **that document is part of the change**, not a
follow-up.

## 2. Column conventions

| Concern | Rule |
|---|---|
| Primary key | `uuid`, generated |
| Timestamps | `timestamptz`, always. Never `timestamp` — it loses the offset. |
| Money | `bigint` minor units + a `char(3)` currency column. Never `float`, `real`, or a bare `numeric`. |
| Money naming | Always suffixed `_minor` / `Minor`. The suffix makes `amount / 100` look wrong at the call site. |
| Soft delete | `deleted_at timestamptz NULL` — **only** where history matters (expenses, settlements, users, groups). Elsewhere delete means delete. |
| Booleans | Predicate names: `is_settled`, `simplify_debts` |
| Enums | Postgres enum, singular PascalCase in TS |

```ts
@Column({ type: 'bigint', name: 'amount_minor', transformer: bigintTransformer })
amountMinor!: bigint;

@Column({ type: 'char', length: 3 })
currency!: string;
```

`bigint` comes back from the driver as a string — always attach the transformer, or you get
string concatenation where you expected addition.

## 3. Relations and indexes

- Every foreign key gets an index. **Postgres does not create one automatically**, and an
  unindexed FK makes every join and cascade slow.
- Add composite indexes for filter+sort pairs: `expenses(group_id, paid_at DESC)`.
- Partial indexes where soft deletes dominate: `WHERE deleted_at IS NULL`.
- Set `onDelete` explicitly. Think about whether a cascade is correct — deleting a user must
  **not** cascade to their expenses, because other people's balances depend on them.
- Add check constraints for what the database can enforce: amounts `> 0`,
  `from_user_id <> to_user_id`.

## 4. Generate and review the migration

```bash
npm run migration:generate -- src/database/migrations/AddExpenseCategory
```

**Read the generated SQL.** The generator is a diffing tool, not a DBA:

- [ ] Is it dropping anything? A **rename** appears as `DROP COLUMN` + `ADD COLUMN`, which
      destroys the data. Rewrite as `ALTER TABLE ... RENAME COLUMN`.
- [ ] Does `down()` genuinely reverse `up()`? The generator often emits an incomplete one.
- [ ] Are new foreign keys indexed?
- [ ] Is a new `NOT NULL` column safe on a non-empty table? It needs a default, or a
      three-step add → backfill → constrain.
- [ ] Does existing data need backfilling? The generator cannot know.

Then verify the reversal actually works:

```bash
npm run migration:run
npm run migration:revert
npm run migration:run
```

This is not optional. A broken `down()` is discovered during an incident.

## 5. Never

- Edit a migration that has already merged to `main`. Someone has run it. Write a new one.
- Reference a TypeScript entity from a migration. Entities change; a migration must mean the
  same thing forever. Write raw SQL.
- Set `synchronize: true`. See [ADR-0001](../../../docs/adr/0001-typeorm-with-migrations.md).

## 6. Finish the change

- Update [docs/data-model.md](../../../docs/data-model.md) — the table, its columns, and any
  new invariant.
- If the entity is group-owned, confirm every query path filters by membership and, for
  ledger tables, by `deleted_at IS NULL`.
- Add or update factories in `test/factories/` so tests can build the new shape.

## Reference

- [docs/database.md](../../../docs/database.md) — full migration workflow
- [docs/data-model.md](../../../docs/data-model.md) — tables and invariants
