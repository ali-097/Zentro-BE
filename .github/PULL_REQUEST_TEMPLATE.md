<!--
Keep it small. A 200-line PR gets a real review; a 2,000-line PR gets a rubber stamp.
-->

## What and why

<!-- What changed, and what problem it solves. The diff shows the what — explain the why. -->

Closes #

## How I tested it

<!--
Not "CI passed". What did you actually exercise? A curl command, a failing-then-passing
test, a scenario you stepped through.
-->

## Checklist

- [ ] `npm run lint && npm run typecheck && npm test` pass locally
- [ ] Tests added for the behaviour this changes — including the failure cases
- [ ] No entity returned from a controller (response DTOs only)
- [ ] Every new request DTO field has a `class-validator` decorator
- [ ] Swagger annotations complete on new or changed routes

### If this touches money

- [ ] Amounts stay `bigint` minor units — no floats, no division outside `src/common/money/`
- [ ] Splits sum exactly to the expense total, with a test proving it
- [ ] Balance queries exclude soft-deleted rows

### If this touches group-scoped data

- [ ] Route is guarded by `GroupMemberGuard` / `GroupAdminGuard`
- [ ] The query itself is also scoped by membership — not relying on the guard alone
- [ ] Test asserts a non-member receives **404**

### If this changes the schema

- [ ] Migration committed, and `down()` verified by actually running a revert
- [ ] New foreign keys are indexed
- [ ] `docs/data-model.md` updated

### If this changes the API contract

- [ ] Paired Zentro-FE issue linked below — the client generates its types from our OpenAPI
- [ ] Breaking changes are additive-then-deprecate, not a rename in place

Paired frontend issue:

### If this is a decision

- [ ] ADR added in `docs/adr/`, linked here

## Notes for the reviewer

<!-- Anything you're unsure about, or want a second opinion on. -->
