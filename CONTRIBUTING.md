# Contributing to Zentro API

## Getting set up

See the [Quickstart](./README.md#quickstart) and, if anything misbehaves,
[docs/runbooks/local-dev.md](./docs/runbooks/local-dev.md).

## Picking work

All work lives on the shared **Zentro project board**, which spans this repo and
[Zentro-FE](https://github.com/ali-097/Zentro-FE).

- Anything in the **M0 Foundation** milestone comes first. It is all `priority:P0` and it
  blocks feature work — M1+ issues assume M0 has landed.
- Filter by `good-first-issue` if you're new to the codebase.
- Assign yourself before starting, and move the card to **In progress**. If you stop working
  on something, unassign — a stale assignment is worse than an empty one.

## Branching

Branch from `main`. `main` is protected: no direct pushes, PR + 1 approval + green CI.

```
feat/42-group-invites        # feature, with the issue number
fix/58-split-rounding        # bug fix
chore/ci-postgres-service    # tooling, docs, dependencies
spike/vitest-migration       # timeboxed investigation, not meant to merge as-is
```

## Commits

[Conventional Commits](https://www.conventionalcommits.org/). `commitlint` enforces this on
commit, so a malformed message fails immediately rather than in CI.

```
feat(expenses): support percentage splits
fix(auth): reject login when password_hash is null
chore(deps): bump typeorm to 0.3.29
docs(adr): record FX snapshotting decision
refactor(groups): move membership check into a guard
test(money): add property-based cases for penny allocation
```

Scope is the module name. Breaking changes get a `!` (`feat(api)!: ...`) and a
`BREAKING CHANGE:` footer — and since the frontend generates its client from our OpenAPI
document, **a breaking change here breaks another repo**. See
[Versioning](./docs/api/README.md#versioning-and-breaking-changes).

Write the message for someone reading `git log` in a year. The *what* is in the diff; put
the *why* in the body.

## Pull requests

Fill in the template — it isn't ceremony, it's the review checklist:

1. **What and why**, linked to the issue (`Closes #42`).
2. **How you tested it.** "CI passed" is not testing. Say what you actually exercised.
3. **Screenshots or `curl` output** for anything with a visible API surface change.
4. **Paired frontend issue** linked, if this changes the API contract.

Keep PRs small. A 200-line PR gets a real review; a 2,000-line PR gets a rubber stamp, and
that is how bugs reach `main`.

Before requesting review:

```bash
npm run lint && npm run typecheck && npm test
```

## The review bar

A reviewer is checking:

- **Correctness of the money math** above everything else. Splits summing exactly, no
  floats, no rounding invented locally instead of using `src/common/money/`.
- **Authorization.** Every group-scoped route guarded; every group-scoped query filtered by
  membership. A route that trusts a UUID from the client is a blocking finding.
- **No entity returned from a controller.** Entities carry hashes and soft-delete columns.
- **A migration exists** for any entity change, and its `down()` genuinely reverses `up()`.
- **Tests exist**, including the unauthorized case — not just the happy path.
- **Layering respected** — no repository in a controller, no `Request` in a service.

Approve when you'd be comfortable being paged for it. Request changes plainly and say why;
"consider..." on something that actually matters just costs another round trip.

## Architecture decisions

Anything that would make a new engineer ask *"why is it like this?"* gets an ADR in
[docs/adr/](./docs/adr/). Copy `0000-template.md`, take the next number, and link it from
the PR. This includes reversing an existing decision — supersede the old ADR rather than
editing it, so the reasoning stays readable.

Adding a dependency counts as a decision. Say what it replaces and what it costs.

## Documentation

Docs live next to the code and are part of the change, not a follow-up:

- New table or changed invariant → [docs/data-model.md](./docs/data-model.md)
- New endpoint → Swagger decorators (the OpenAPI doc is generated, not written by hand)
- New environment variable → `.env.example` **and** the config schema, or the app won't boot
- New setup step → [docs/runbooks/local-dev.md](./docs/runbooks/local-dev.md)

If following the README from a clean clone doesn't work, that's a bug — file it.

## Using AI agents

Read [AGENTS.md](./AGENTS.md) — it carries the rules that cause real bugs when broken. You
own what you submit; "the agent wrote it" is not a defence in review. Pay particular
attention to generated money handling and generated queries that skip the membership filter.
