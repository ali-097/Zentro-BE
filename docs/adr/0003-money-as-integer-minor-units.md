# ADR-0003: Store money as integer minor units

- **Status:** Accepted
- **Date:** 2026-09-06

## Context

Zentro is a ledger. Its entire value proposition is that the numbers are right — a
cent that appears or disappears is not a cosmetic bug, it is the product failing.

Three representations were available:

- IEEE-754 floats (`number` in JS, `double precision` in Postgres)
- Arbitrary-precision decimals (`numeric` + a decimal library)
- Integer minor units (`1230` = £12.30)

Floats cannot represent most decimal fractions exactly. `0.1 + 0.2 === 0.30000000000000004`.
In a system that repeatedly divides totals across members and sums them back, that error
compounds and surfaces as a group whose balances don't reconcile to zero — with no obvious
cause and no way to reconstruct the truth after the fact.

## Decision

Every monetary amount is stored and transported as a **`bigint` of the currency's minor
unit**, paired with an ISO-4217 currency code.

- Database: `amount_minor bigint NOT NULL`, `currency char(3) NOT NULL`
- Wire: `{ "amountMinor": 1230, "currency": "EUR" }`
- Field names carry a `Minor` / `_minor` suffix, always
- All arithmetic on amounts lives in `src/common/money/`
- Formatting for display is the client's responsibility

`bigint` rather than `int` because minor units of a low-denomination currency reach large
numbers quickly, and a ledger should not have a headroom cliff.

## Consequences

**Good**
- Exact arithmetic. Sums, comparisons and equality all behave.
- Splits sum to the total precisely, so the ledger's core invariant is enforceable.
- The `Minor` suffix makes `amount / 100` look wrong at the call site, where it is easiest
  to catch in review.
- Same representation end to end — no conversion boundary to get wrong.

**Bad**
- Every read and write needs mental conversion; `1230` is less readable than `12.30`.
- Zero-decimal currencies (JPY, KRW) and three-decimal ones (BHD, KWD) have different
  exponents, so the exponent must come from currency metadata rather than a hardcoded 100.
- `bigint` in JS is not JSON-serializable by default and needs an explicit transformer.
- Division must be centralized, which is a discipline the language doesn't enforce.

**Neutral**
- Display formatting moves to the client, which is the correct place anyway — it knows the
  user's locale.

## Alternatives considered

**Floats.** Rejected outright. The failure mode is silent, cumulative, and unrecoverable.

**Postgres `numeric` + decimal.js.** Genuinely correct and more readable in the database.
Rejected because it pushes exactness onto every developer remembering to use the decimal
type: a single `Number(row.amount)` reintroduces the float bug invisibly. Integers make the
wrong thing hard rather than merely discouraged. It also costs a dependency and slower
arithmetic for a benefit that is mostly readability during debugging.

**Strings.** Exact in transit, but every operation requires parsing, and it moves the
problem rather than solving it.

## When to revisit

If Zentro ever needs sub-minor-unit precision — per-unit pricing, interest, fractional
allocations. Nothing in the current or planned scope requires it.
