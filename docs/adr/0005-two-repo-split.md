# ADR-0005: Keep the API and client in separate repositories

- **Status:** Accepted
- **Date:** 2026-09-06

## Context

Zentro started as two repositories — `zentro-be` and `zentro-fe` — created on the same day,
by default rather than by decision. Before building out documentation, CI and a backlog, it
was worth deciding whether to consolidate, because that choice determines where all of it
lives.

Both are early enough that merging would have cost little.

## Decision

**Keep the two repositories separate.** Bridge the gaps deliberately:

- One **GitHub Project board spanning both repos** — the single place work is tracked, so
  the split isn't visible when planning.
- An **OpenAPI contract** with drift detection in CI ([ADR-0004](./0004-openapi-as-cross-repo-contract.md)).
- **Identical conventions** in both: same label taxonomy, same milestones, same
  `AGENTS.md`/`CLAUDE.md` structure, same PR and issue templates, same branch protection.

Cross-repo work is filed as paired issues that link to each other.

## Consequences

**Good**
- Independent CI: a frontend change doesn't run backend tests, and pipelines stay fast and
  obviously relevant.
- Independent deploys, with no coupling between an API release and a client release.
- Clear ownership boundaries; smaller, more focused checkouts.
- No monorepo tooling (workspaces, Nx, task graphs) to learn or maintain.

**Bad**
- **No shared types.** The main cost, mitigated but not eliminated by ADR-0004.
- A change spanning both repos needs two PRs, merged in a compatible order.
- Tooling and config are duplicated and can drift. Deliberate discipline required.
- Issues live in two trackers; the project board is what makes this bearable, and if the
  board is neglected the split becomes painful.
- No single commit represents a full-stack feature.

**Neutral**
- Two READMEs, two contributing guides. More files, but each is shorter and more relevant to
  its reader.

## Alternatives considered

**Single monorepo (npm workspaces): `apps/api`, `apps/web`, `packages/shared`.** Technically
the stronger option — genuinely shared types, one CI pipeline, one board, atomic full-stack
commits, no drift possible. Rejected by the project owner, who preferred to keep the existing
separation. The mitigations above exist specifically to buy back most of what this would have
provided.

**Two code repos plus a third documentation repo.** Centralizes planning but adds a third
place to look and separates docs from the code they describe, which is how docs go stale.

## When to revisit

If any of these become true, reconsider:

- Cross-repo type drift causes a production bug despite the OpenAPI check.
- Coordinating paired PRs becomes a routine source of friction.
- A third deployable appears (mobile client, worker) — three repos multiplies the cost.
