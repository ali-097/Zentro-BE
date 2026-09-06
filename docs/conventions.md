# Code conventions

Not style preferences — Prettier and ESLint handle those and are not up for debate. These
are the conventions a linter can't enforce.

## Naming

| Thing | Convention | Example |
|---|---|---|
| Files | kebab-case, suffixed by role | `create-expense.dto.ts` |
| Classes | PascalCase, suffixed by role | `ExpensesService`, `GroupMemberGuard` |
| Database | snake_case, tables plural | `expense_splits.amount_minor` |
| Wire format | camelCase | `amountMinor` |
| Booleans | a predicate | `isSettled`, `hasAttachments` — not `settled`, `flag` |
| Money fields | **always** suffixed `Minor` / `_minor` | `amountMinor` |
| Enums | singular PascalCase, SCREAMING values | `SplitType.PERCENTAGE` |

The `Minor` suffix is a deliberate friction. `amount` tells you nothing; `amountMinor` makes
`amountMinor / 100` look as wrong as it is.

## Money

Non-negotiable, restated because it is the thing most likely to be got wrong:

```ts
// Never
const share = total / members.length;        // float; loses pennies
const eur = `€${amount}`;                    // formatting is the client's job

// Always
const shares = allocate(totalMinor, weights); // from src/common/money
```

- `bigint` minor units + ISO-4217 code. Never `number` for an amount that could exceed
  `Number.MAX_SAFE_INTEGER`, never a float at any point in the pipeline.
- Never divide an amount outside `src/common/money/`. Division is where pennies vanish.
- Never format currency server-side.
- Never compare amounts across currencies without converting through a snapshotted rate.

## Async

- `async`/`await` throughout. No raw `.then()` chains, no mixing the two.
- Every multi-write operation runs in a **transaction**. Creating an expense writes to
  `expenses`, `expense_payers`, `expense_splits` and `activities` — a partial write there
  corrupts the ledger. Use the transaction helper, not four sequential saves.
- Don't `await` inside a loop over independent work. `Promise.all` it.

## Errors

```ts
// In a service — domain exception, HTTP-blind
if (splitTotal !== expense.amountMinor) {
  throw new SplitMismatchError(splitTotal, expense.amountMinor);
}

// Never in a service
throw new BadRequestException('...');   // couples business logic to HTTP
```

- Services throw domain errors from `common/errors/`. The global filter maps them.
- Never swallow an error to return a default. A caught error is either handled meaningfully
  or rethrown.
- Never put a raw database error message in a client-facing response — it leaks schema.
- Log at the point you have the most context, once. Errors logged at three layers produce
  three alerts for one incident.

## Queries

- **Every group-scoped query filters by membership.** Not "the guard already checked" — the
  guard and the query can drift. Both.
- **Every ledger query filters `deleted_at IS NULL`.** The most common way to compute a wrong
  balance is forgetting this.
- Aggregate in SQL. If you're summing in JavaScript, you're loading rows you shouldn't.
- No N+1. Use `relations` or an explicit join. A group feed that queries per expense will be
  fine locally with 5 expenses and unusable with 500.
- Never interpolate user input into a query string, including `ORDER BY` fields. Allowlist
  sort columns.

## DTOs

- Request DTOs decorate **every** property with `class-validator`. Undecorated properties are
  rejected by `forbidNonWhitelisted`, which reads as a mystery 400.
- Response DTOs are explicit classes with `@ApiProperty`. No `Partial<Entity>`, no spreading
  an entity into a response.
- Query parameters are input. Validate them like a body.

## Tests

- Name the behaviour, not the method:
  `it('gives the leftover penny to the lowest user id')`, not `it('works')`.
- One assertion *concept* per test.
- **Every group-scoped route has a test asserting a non-member gets 404.** This is the class
  of bug most likely to reach production unnoticed.
- Money logic gets exhaustive cases: odd totals, indivisible amounts, single member, zero
  weights, very large amounts.
- No shared mutable state between tests. Each builds its own fixtures.

## Comments

Comment the **why**, never the what:

```ts
// Bad — restates the code
// increment the counter
counter++;

// Good — records a decision the code can't express
// Largest-remainder rather than round-half-up: guarantees the shares sum to the
// total exactly, which round-half-up does not for e.g. 10.00 across 3 people.
```

Anything that made you pause for thirty seconds deserves a comment. Anything that took an
afternoon deserves an ADR.

## TypeScript

- `strict` is on and stays on.
- No `any`. `unknown` plus narrowing where a type is genuinely unknown.
- No non-null assertions (`!`) to silence the compiler — if it might be null, handle it.
- Prefer `readonly` for injected dependencies and value objects.
- Type inference is fine for locals; be explicit at every module boundary.
