# Architecture Decision Records

Short documents recording decisions that shape this codebase, and — more importantly — the
reasoning behind them.

The point isn't ceremony. It's that six months from now someone will look at a piece of code,
think "this is needlessly awkward", and change it. An ADR is how you tell that person what
they'd be trading away.

## Index

| # | Decision | Status |
|---|---|---|
| [0001](./0001-typeorm-with-migrations.md) | Keep TypeORM, replace `synchronize` with migrations | Accepted |
| [0002](./0002-jwt-refresh-rotation.md) | In-house auth with rotating refresh tokens | Accepted |
| [0003](./0003-money-as-integer-minor-units.md) | Store money as integer minor units | Accepted |
| [0004](./0004-openapi-as-cross-repo-contract.md) | OpenAPI is the contract between the two repos | Accepted |
| [0005](./0005-two-repo-split.md) | Keep the API and client in separate repositories | Accepted |
| [0006](./0006-fx-rate-snapshotting.md) | Snapshot FX rates onto the expense | Accepted |

## Writing one

Copy [`0000-template.md`](./0000-template.md), take the next number, link it from your PR.

**Write an ADR when** a choice would make a newcomer ask "why is it like this?" — adding or
replacing a dependency, a data representation, a security or auth mechanism, a boundary
between layers or services, or anything you deliberately chose *not* to do.

**Don't write one for** ordinary implementation choices, anything a linter enforces, or
things obvious from the code.

## Changing a decision

Never edit an accepted ADR to reverse it. Write a new one, and mark the old one
`Superseded by ADR-XXXX`. The old reasoning is the valuable part — it tells you what the
new decision has to be better than.
