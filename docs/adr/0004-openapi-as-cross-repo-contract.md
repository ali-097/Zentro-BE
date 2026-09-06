# ADR-0004: OpenAPI is the contract between the two repos

- **Status:** Accepted
- **Date:** 2026-09-06

## Context

Zentro's API and client live in separate repositories (see
[ADR-0005](./0005-two-repo-split.md)). That split has one serious cost: there is no shared
package, so nothing structurally prevents the client's idea of a response from drifting away
from what the server actually returns.

Hand-maintained TypeScript interfaces on the client are the usual answer, and they rot. A
renamed field compiles cleanly on both sides and fails at runtime, in front of a user.

## Decision

**The generated OpenAPI document is the contract.**

1. The API annotates every route and DTO with `@nestjs/swagger` decorators. Swagger UI is
   served at `/docs`.
2. On merge to `main`, CI runs `npm run openapi:emit` and commits `openapi.json` to the repo
   root.
3. Zentro-FE's `npm run api:sync` fetches that file and regenerates typed models into
   `src/app/core/api/generated/`. Generated files are committed.
4. **Zentro-FE's CI regenerates and fails if the result differs from what's committed.**

Step 4 is what makes this real rather than aspirational — drift becomes a red build instead
of a runtime surprise.

## Consequences

**Good**
- The client's types are derived from the server's actual behaviour, not from someone's
  memory of it.
- Breaking changes surface as a failing build in the other repo, quickly.
- Swagger UI is a genuinely useful, always-current API explorer — no separate doc to update.
- Missing annotations become visible, because they produce `any` downstream.

**Bad**
- Swagger decorators are boilerplate on every route and DTO, and are easy to forget.
- The generated document is only as good as the annotations. An unannotated response type
  silently degrades to `any`, which is worse than an error because nothing complains.
- Two repos must be updated in the right order for a breaking change: add, deprecate,
  migrate the client, remove.
- Committing generated files creates occasional merge conflicts. Regenerate, don't
  hand-merge.

**Neutral**
- `openapi.json` in git makes API changes visible in the diff, which is useful in review.

## Alternatives considered

**A shared npm package of types.** The cleanest answer, and the reason monorepos exist.
Rejected as a consequence of ADR-0005: publishing and versioning a package across two repos
is more overhead than generating from a document, and it would still be hand-written rather
than derived from the implementation.

**Hand-written interfaces in the client.** Zero tooling. Rejected — this is exactly the
drift the decision exists to prevent.

**tRPC or similar end-to-end type inference.** Excellent when both ends are TypeScript in one
repo. Rejected: requires a shared build graph, and abandons a documented REST surface the
project may want for a future mobile client.

**Contract tests (Pact).** Verifies behaviour rather than shape, which is stronger. Rejected
as disproportionate for a two-service, small-team project — schema drift is the actual
failure mode, and generation catches it for far less effort.

## When to revisit

If the repos merge into a monorepo, replace this with a shared types package.
