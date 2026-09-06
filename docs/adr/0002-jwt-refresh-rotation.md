# ADR-0002: In-house auth with rotating refresh tokens

- **Status:** Accepted
- **Date:** 2026-09-06

## Context

Zentro needs authentication with email/password and Google sign-in. It is a personal project
with no budget, so a paid identity provider was ruled out on cost. The remaining question
was how sessions are represented and stored.

The common shortcut — a long-lived JWT in `localStorage` — is unacceptable here:
`localStorage` is readable by any XSS payload, and a stateless JWT cannot be revoked, so a
stolen token stays valid until it expires. For an app holding a financial ledger, "log out
everywhere" has to actually work.

## Decision

Auth is implemented in-house with a **split token model**:

| | Access token | Refresh token |
|---|---|---|
| Format | JWT (HS256) | Opaque 256-bit random |
| Lifetime | ~15 minutes | ~30 days |
| Transport | `Authorization: Bearer` | httpOnly cookie, scoped to `/api/v1/auth` |
| Client storage | Memory only | Unreachable from JavaScript |
| Server storage | None | SHA-256 hash |

Passwords use **argon2id**. Google sign-in uses the authorization code flow with PKCE,
linked by the provider's stable subject id.

Refresh tokens **rotate on every use** and are tracked as a family. Presenting a token that
has already been rotated is treated as theft: the entire family is revoked and the user must
log in again.

## Consequences

**Good**
- XSS cannot read the refresh token — it is httpOnly.
- A stolen access token is useful for at most fifteen minutes.
- Sessions are genuinely revocable; logout and password reset kill them server-side.
- Reuse detection turns a silent compromise into a detectable, contained event.
- No vendor, no cost, no user data in a third party.

**Bad**
- Meaningfully more code than a managed provider: rotation, families, reuse detection,
  verification and reset flows, all of which need tests.
- We own the security of it, including future issues.
- Cookies force a strict CORS allowlist and `credentials: 'include'`, which is a recurring
  source of local-setup confusion.
- Token state means the refresh endpoint hits the database — the one non-stateless path.
- Reuse detection can log out a legitimate user, e.g. when two tabs race a refresh. Accepted:
  an occasional surprise logout beats an undetected persistent session.

**Neutral**
- The client must handle 401 → refresh → retry. Done once in an interceptor.

## Alternatives considered

**Managed provider (Clerk / Auth0 / Supabase Auth).** Better security defaults, far less
code, social login and MFA for free. Rejected: cost at scale, a vendor dependency for the
most critical path in the app, and user records split across two systems — every group
member reference would need reconciling against an external id.

**Long-lived JWT in `localStorage`.** Simplest. Rejected: XSS-readable and unrevocable.

**Server-side sessions with an opaque cookie only.** Simple and revocable, but every request
hits the session store, and it fits a cookie-only browser client rather than an API that may
later serve a mobile app.

**Non-rotating refresh tokens.** Most of the benefit for less work. Rejected because
rotation is what makes theft *detectable*; without it a stolen refresh token grants thirty
days of silent access.
