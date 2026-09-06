---
name: api-review
description: Audit a Zentro API diff before opening a PR - checks authorization, money handling, DTO leakage, validation, Swagger coverage, migrations and test coverage against this repo's conventions. Use before requesting review.
---

# Review an API change

Audit the diff (`git diff main...HEAD`) against the checks below. Report findings ordered by
severity, each with the file, the line, and what specifically goes wrong. Do not report
style — the linter covers that.

## Blocking — do not open the PR with these unresolved

### Authorization

The highest-risk category in this codebase. A group id is a UUID in a URL; knowing it must
never be sufficient.

- Every group-scoped route carries `GroupMemberGuard` or `GroupAdminGuard`.
- **Every group-scoped query is also scoped by membership in the query itself.** "The guard
  checks it" is not sufficient — guards get dropped in refactors, and a query that trusts one
  fails open.
- No `findOne(id)` on a group-owned record without a membership predicate.
- Non-members get **404**, not 403. A 403 confirms the resource exists and enables
  enumeration.
- Cross-entity references validated: every `userId` in an expense's splits is a member of
  *that* group. Otherwise a member can invent debts for strangers.

### Money

- No floats anywhere in the path. No `number` arithmetic on an amount.
- No division outside `src/common/money/`.
- Splits sum exactly to the total; payers sum exactly to the total.
- No `toBeCloseTo` in a money assertion — if it is needed, a float has entered the pipeline
  and that is the bug.
- Balance and ledger queries filter `deleted_at IS NULL`. Forgetting this is the most common
  way to produce a wrong balance.
- Cross-currency amounts use the snapshotted `fx_rate`, never a freshly fetched one.

### Data leakage

- **No entity returned from a controller.** Entities carry `password_hash`, `token_hash`,
  `deleted_at`. Responses are explicit DTOs.
- No token, hash, cookie or `Authorization` header in a log line.
- No raw database error text in a client-facing `detail` — it leaks schema.

### Validation

- Every request DTO property has a `class-validator` decorator. An undecorated property is
  rejected by `forbidNonWhitelisted` and reads as a mystery 400.
- Query parameters have a DTO too.
- `ORDER BY` fields come from an allowlist, never interpolated user input.

## Important — fix before merge

### Layering

- Controllers contain no business logic and inject no repository.
- Services import nothing HTTP-shaped: no `Request`, `Response`, or `HttpException`. They
  throw domain errors from `common/errors/`.
- No imports reaching into another module's internals — go through its exported service.

### Persistence

- Multi-table writes are wrapped in a transaction. Creating an expense touches four tables;
  a partial write violates the split-sum invariant.
- No HTTP call (FX, email, storage) inside a transaction.
- No N+1: check for queries inside loops.
- Schema change has a migration, and `down()` was actually run.

### Contract

- Every new or changed route has `@ApiOperation` and an `@ApiResponse` per status it can
  return; DTOs have `@ApiProperty`. **Missing annotations become `any` in the frontend**,
  which is worse than an error because nothing complains.
- Breaking changes are additive-then-deprecate, not a rename in place, and have a paired
  Zentro-FE issue linked.

### Tests

- Every group-scoped route has a non-member-gets-404 test. **Mandatory.**
- Money logic covers odd totals, indivisible amounts, single member, large amounts.
- Tests assert behaviour, not implementation — not "called save twice".

## Worth mentioning

- Anything that took real thought and has no comment explaining *why*.
- Any decision that should be an ADR.
- `docs/data-model.md` not updated alongside a schema or invariant change.

## Output

For each finding: **severity · file:line · what is wrong · what would go wrong in
production.** If nothing blocking is found, say so plainly rather than inventing findings —
a review that always produces results teaches people to ignore it.
