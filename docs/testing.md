# Testing

## The three levels

| Level | Runs | Needs Postgres | Lives in |
|---|---|---|---|
| **Unit** | `npm test` | No | `src/**/*.spec.ts`, beside the code |
| **Integration** | `npm run test:e2e` | Yes | `test/**/*.e2e-spec.ts` |
| **Migration** | CI | Yes | `.github/workflows/ci.yml` |

The split is about **whether a database is required**, not about the style of assertion.

## What gets tested where

**Unit — the business logic that must never be wrong.** No database, no HTTP, no mocks of
things you own. This is where the money code lives, and it should be tested to a standard
that looks excessive:

- Split allocation across every split type
- Penny remainder distribution — odd totals, indivisible amounts, one member, large amounts
- Balance arithmetic
- Debt simplification
- Token generation, hashing, expiry, rotation

**Integration — the wiring.** A real request through guards, pipes, service, database and
serialization. This is where you find the bugs unit tests structurally cannot see: a missing
guard, a DTO that leaks a hash, a transaction that doesn't roll back.

Every endpoint gets at least:
1. Authorized success
2. **Unauthenticated → 401**
3. **Authenticated non-member → 404** (for anything group-scoped)
4. Invalid input → 400/422

**Migration — schema integrity.** CI runs every migration against an empty database, then
asserts that generating a new migration produces **no diff**. This catches the case where
someone changes an entity and forgets the migration, which otherwise only surfaces in
production.

## Non-negotiables

**Every group-scoped route has a non-member-gets-404 test.** Broken object authorization is
this app's top risk (see [security.md](./security.md)) and it passes code review easily —
the happy path works perfectly. Reviewers should block PRs that omit it.

**Balances sum to zero.** Any test that builds a group with expenses should assert that the
members' balances total exactly zero. It's one line and it catches nearly every possible
corruption of the ledger.

**Money assertions are exact.** `toBe(1230)`, never `toBeCloseTo`. If a test needs
`toBeCloseTo` for an amount, a float has entered the pipeline and that's the bug.

## Data

Tests build their own data through **factories** in `test/factories/`:

```ts
const group = await aGroup().withMembers(alice, bob, carol).build();
const expense = await anExpense().inGroup(group).paidBy(alice).amount(1000).splitEqually().build();
```

- No shared mutable state between tests — each builds what it needs.
- Never depend on `npm run seed`. Seeds are for humans looking at the app.
- Each integration test runs in a transaction that is rolled back afterwards, so tests are
  order-independent and the database stays clean.

## Naming

Describe the behaviour and the condition:

```ts
it('gives the leftover penny to the lowest user id');
it('returns 404 when the caller is not a member of the group');
it('rejects a login when the account has no password hash');

// not
it('works');
it('test split');
```

Somebody reading a CI failure should understand what broke without opening the file.

## Running things

```bash
npm test                          # unit
npm run test:watch                # unit, watch mode
npm run test:cov                  # unit + coverage report
npm run test:e2e                  # integration — needs the test database up
npm test -- money                 # filter by filename
npm test -- -t "leftover penny"   # filter by test name
```

Integration tests need Postgres:

```bash
docker compose up -d db
```

If `test:e2e` fails to connect, that's almost always the cause. Check `docker compose ps`
before debugging the test itself.

## Coverage

No enforced global percentage — a number that can be gamed by testing getters. What matters:

- `src/common/money/` — effectively 100%. It is small, pure, and catastrophic when wrong.
- Every service's business rules — covered.
- Every endpoint — at least the four integration cases above.

Controllers with no logic don't need unit tests; their integration test is the test.

## What not to test

- Framework behaviour. NestJS routes correctly; TypeORM saves correctly.
- Getters, DTO shapes, or anything with no branching.
- Implementation detail. Test that creating an expense produces the right splits — not that
  it called `save` twice. The second breaks on every refactor and tells you nothing.
