# Security

How authentication and authorization work, and what specifically can go wrong in an app
that tracks who owes whom money.

Reporting a vulnerability: [SECURITY.md](../SECURITY.md). Please don't open a public issue.

---

## Threat model in one line

Zentro holds a shared financial ledger between people who know each other. The damage isn't
mass data theft — it's **one user reading or altering another group's money**. Design
accordingly: broken object-level authorization is the top risk, not exotic attacks.

---

## Authentication

### Passwords

- **argon2id**, not bcrypt: memory-hard, so GPU cracking is expensive. Parameters live in
  config so they can be raised without a code change.
- Never logged, never returned, never included in a DTO. `password_hash` is `@Exclude()`d
  and controllers return DTOs, giving two independent barriers.
- `password_hash` is **nullable** — Google-only accounts have none. **Every comparison must
  reject a null hash explicitly.** Forgetting this is either a 500 or, worse, a bypass.
- Minimum length enforced, common-password list rejected. No composition rules (forced
  symbols produce `Password1!` and nothing else).
- Login timing is equalized: run a dummy hash comparison for unknown emails so response time
  doesn't reveal which addresses are registered.

### Tokens

| | Access token | Refresh token |
|---|---|---|
| Format | JWT, signed HS256 | Opaque random, 256-bit |
| Lifetime | ~15 min | ~30 days |
| Transport | `Authorization: Bearer` | httpOnly cookie |
| Client storage | Memory only | Never readable by JS |
| Stored server-side | No | Yes, as a SHA-256 hash |

**Why the split.** A JWT in `localStorage` is readable by any XSS payload and can't be
revoked. Keeping the access token in memory limits the window to 15 minutes, and putting the
refresh token in an httpOnly cookie puts it out of JavaScript's reach entirely.

Cookie flags: `httpOnly`, `Secure` (production), `SameSite=Lax`, `Path=/api/v1/auth`, and an
explicit expiry. `SameSite=Lax` plus a CORS allowlist is what prevents CSRF here.

### Rotation and reuse detection

Every refresh **consumes** the old token and issues a new one in the same family.

```
login → T1
T1 refresh → T2   (T1.replaced_by = T2)
T2 refresh → T3
T1 presented again → REUSE. Revoke the entire family. Force re-login.
```

If a token is stolen, either the attacker or the real user will eventually present a spent
token. That's the signal, and the response is to kill every session in the family rather
than just the replayed token. Users may notice an unexpected logout; that's the correct
trade against a persistent silent session.

Logout revokes the family server-side and clears the cookie. A logout that only clears the
client is not a logout.

### Google OAuth

- Authorization code flow with PKCE and a `state` parameter (CSRF on the callback).
- Linked by the provider's **stable subject id**, never the email — emails change hands.
- An unverified email from a provider is **not** trusted to auto-link to an existing account;
  that's an account-takeover path.

### Verification and reset tokens

Single-use, hashed at rest, short-lived (1 h reset, 24 h verification), invalidated on use.
`POST /auth/forgot-password` returns **200 regardless of whether the email exists** — a
different response is an account enumeration oracle. Password reset revokes all refresh
token families, on the assumption the account may be compromised.

---

## Authorization

**The part most likely to be got wrong.** A group id is a UUID in a URL. Knowing it must
never be sufficient to read the group.

### Two layers, always both

```ts
// Layer 1 — the guard, declarative
@UseGuards(GroupMemberGuard)
@Get('groups/:groupId/expenses')

// Layer 2 — the query, scoped
this.repo.find({ where: { groupId, group: { members: { userId, leftAt: IsNull() } } } });
```

Belt and braces, deliberately. Guards get removed during refactors; a query that is scoped
on its own still fails safe. A query that trusts the guard fails open.

### Rules

1. **Never `findOne(id)` on a group-owned record without a membership predicate.**
2. **Return 404, not 403, to non-members.** 403 confirms the resource exists.
3. **Re-check on every request.** Membership is not cached in the JWT — being removed from a
   group must take effect immediately, not in fifteen minutes.
4. **Role checks are separate from membership checks.** `GroupMemberGuard` then
   `GroupAdminGuard`.
5. **Validate cross-entity references.** When creating an expense, assert every `userId` in
   the splits is a member of *that* group. Otherwise a member can invent debts for strangers.

### Test requirement

Every group-scoped route has an integration test asserting a **non-member receives 404**.
Not optional, and reviewers should block a PR that omits it — this is exactly the bug class
that passes code review and reaches production.

---

## Input handling

- Global `ValidationPipe` with `whitelist` + `forbidNonWhitelisted`: unknown properties are
  rejected, so mass assignment isn't possible.
- All queries are parameterized. **No string interpolation into SQL, ever**, including
  `ORDER BY` — sort fields come from an allowlist.
- Uploads: type verified from **content**, not the filename or client-supplied MIME; size
  capped; stored under a generated key, never the user's filename; served via short-lived
  signed URLs from a non-executing origin. Storage buckets are private.

## Rate limiting

Global limits are generous; auth routes are tight, limited **per IP and per account**:

| Route | Reason |
|---|---|
| `POST /auth/login` | Credential stuffing |
| `POST /auth/register` | Bulk account creation |
| `POST /auth/forgot-password` | Mailbox flooding of a third party |
| `POST /auth/resend-verification` | Same |
| Invite creation | Using the app as a spam relay |

## Transport and headers

`helmet` for standard headers, HSTS in production, TLS terminated at the platform edge.
CORS is an **explicit origin allowlist with `credentials: true`** — a wildcard is
incompatible with cookie auth, which is a useful forcing function.

## Secrets

- Never committed. `.env` is gitignored; `.env.example` carries names and dummy values only.
- Config is validated at boot — a missing `JWT_SECRET` **fails startup** rather than
  defaulting to something weak.
- GitHub secret scanning + push protection enabled on the repo.
- Rotating a JWT signing secret invalidates every access token; refresh tokens survive
  because they're opaque and stored server-side.

## Logging

Log the `requestId`, user id, route and outcome. **Never** log tokens, password hashes,
cookies, `Authorization` headers, or full request bodies from auth routes. The logger has a
redaction list; extend it when adding a sensitive field.

## Known gaps

Tracked, not forgotten — see the M7 milestone:

- No MFA yet.
- No active-session management UI (the data exists in `refresh_tokens`).
- No audit log for administrative actions beyond the activity feed.
- No automated dependency vulnerability alerting beyond Dependabot.
