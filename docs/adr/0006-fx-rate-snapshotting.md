# ADR-0006: Snapshot FX rates onto the expense

- **Status:** Accepted
- **Date:** 2026-09-06

## Context

Zentro supports multi-currency in v1: an expense carries its own currency, a group has a
default currency, and balances are reported in the group's currency. So a rate must be
applied somewhere.

There are only two moments it can be applied: **when the expense is created**, or **when the
balance is read**.

Applying it at read time seems more "correct" — it always reflects today's market. It also
makes debts unreconcilable. If Alice owes Bob €50 recorded from a $54 expense, and the rate
moves overnight, the app now says she owes €51. She pays €50, having been told €50
yesterday, and the balance never reaches zero. Worse, every historical balance in the app
changes every day, so no statement ever agrees with the one before it.

## Decision

**The FX rate is resolved once, when the expense (or settlement) is created, and stored on
the row.** It is never recomputed.

Each expense carries:

| Column | Meaning |
|---|---|
| `amount_minor`, `currency` | What was actually spent |
| `fx_rate` | Rate to the group currency **on the day of creation** (`1` when equal) |
| `amount_group_minor` | The converted amount, denormalized |

`amount_group_minor` is denormalized deliberately so the balance aggregate is a plain sum
with no join to a rates table. Settlements follow the same rule.

Rates come from a daily feed cached in `fx_rates`. If the feed is unavailable, expense
creation in a foreign currency **fails** rather than guessing — a wrong rate written to a
permanent row is worse than a retry.

## Consequences

**Good**
- Balances are stable. A debt of €50 stays €50 until it's paid.
- Debts actually reach zero.
- Historical expenses convert the way they did on the day, which is what a receipt says.
- Balance queries are simple sums — no join, no per-row rate lookup.

**Bad**
- Balances don't reflect today's market rate. For a genuinely volatile pair the recorded
  figure can drift from present-day value. This is the correct trade for a debt ledger, but
  it will occasionally surprise a user.
- A bad rate is permanent once written, and correcting it means voiding and recreating the
  expense.
- Creating a foreign-currency expense depends on an external feed being reachable.
- `amount_group_minor` is denormalized, so changing a group's default currency requires a
  backfill — deliberately not supported in v1.

**Neutral**
- The rate is stored per row rather than looked up, which is slightly more storage for
  considerably simpler queries.

## Alternatives considered

**Convert at read time using the current rate.** Rejected — this is the failure described in
Context. Debts change size daily and never settle.

**Store only the original currency; convert in the client.** Moves the same problem to a
place with less context and no consistency between clients.

**A group-level rate table with effective date ranges.** More flexible, and would allow
retroactive correction of a bad rate. Rejected as disproportionate: it complicates every
balance query to solve a rare problem that void-and-recreate already handles.

## When to revisit

If users report confusion about stale conversions, the answer is to **show** both figures —
the snapshotted amount plus an indicative present-day value — not to change what the ledger
computes.
