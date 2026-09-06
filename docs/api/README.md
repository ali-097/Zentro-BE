# API conventions

The contract this service exposes. The generated OpenAPI document at `/docs` is the
authoritative *surface*; this file is the authoritative *style*.

## Basics

- Base path **`/api/v1`**. Health endpoints (`/healthz`, `/readyz`) sit outside it.
- JSON in, JSON out. `Content-Type: application/json`.
- Resource paths are plural nouns; actions are HTTP verbs, not path segments.
  `POST /groups/:id/members` — not `POST /groups/:id/addMember`.
- Nesting stops at one level. `/groups/:groupId/expenses` is fine;
  `/groups/:g/expenses/:e/splits/:s` is not — expose `/expenses/:id` instead.

## Request and response bodies

**camelCase** on the wire, snake_case in the database. TypeORM and the DTO layer map
between them; neither leaks.

**Money is always a pair**, never a formatted string and never a float:

```json
{ "amountMinor": 1230, "currency": "EUR" }
```

Formatting is the client's job — it knows the user's locale, we don't.

Timestamps are ISO 8601 with an offset: `2026-09-06T14:30:00Z`.

**Responses are DTOs, never entities.** An entity carries `password_hash`, `token_hash` and
`deleted_at`; returning one is how those leak. Map explicitly.

## Status codes

| Code | Use |
|---|---|
| `200` | Successful read or update |
| `201` | Created — include the resource, and a `Location` header |
| `204` | Deleted, or an accepted action with nothing to return |
| `400` | Malformed or failed validation |
| `401` | No valid access token — the client should refresh, then retry |
| `403` | Authenticated, but not permitted (e.g. a member attempting an admin action) |
| `404` | Not found **or** not visible to this user |
| `409` | Conflict — duplicate membership, already-accepted invite, stale version |
| `422` | Semantically invalid — splits that don't sum, settlement to yourself |
| `429` | Rate limited. Includes `Retry-After` |

> **403 vs 404 matters.** For a resource the caller isn't a member of, return **404**.
> Returning 403 confirms the group exists, which lets someone enumerate valid group ids.
> Use 403 only when membership is established but the *role* is insufficient.

## Errors

One envelope for every failure, modeled on RFC 7807:

```json
{
  "type": "https://zentro.app/errors/split-mismatch",
  "title": "Splits do not sum to the expense total",
  "status": 422,
  "detail": "Splits total 999 but the expense is 1000 (EUR minor units)",
  "instance": "/api/v1/expenses",
  "requestId": "01J8XY7K2M3N4P5Q6R7S8T9V0W",
  "errors": [{ "field": "splits", "message": "must sum to amountMinor" }]
}
```

- `type` is a stable machine-readable identifier. Clients branch on it; never on `detail`.
- `errors[]` appears only for field-level validation.
- `requestId` is on every response **and** every log line — it's how a bug report becomes a
  stack trace.

Services throw **domain exceptions** (`GroupNotFoundError`, `SplitMismatchError`,
`InsufficientRoleError`); the global filter maps them to status codes. Services never import
`HttpException` — that would put HTTP knowledge in the business layer.

**Never put a raw database error in `detail`.** It leaks schema.

## Pagination

**Cursor-based**, everywhere. Offset pagination duplicates and skips rows when the
underlying list changes between pages, and an activity feed changes constantly.

```
GET /api/v1/groups/:id/expenses?limit=25&cursor=eyJwYWlkQXQiOi...
```

```json
{
  "data": [ ... ],
  "pageInfo": { "nextCursor": "eyJwYWlkQXQiOi...", "hasNextPage": true }
}
```

`limit` defaults to 25, caps at 100. The cursor is opaque base64 — clients must not parse it.

Collections are **always** wrapped in `data`. Returning a bare array leaves no room to add
`pageInfo` later without breaking every consumer.

## Filtering and sorting

Query parameters, validated by a DTO like any other input:

```
?category=groceries&from=2026-01-01&to=2026-03-31&paidBy=<uuid>&sort=-paidAt
```

`sort` takes a field name, `-` prefix for descending, from an explicit allowlist. Never
interpolate a sort field into SQL.

## Authentication

- Access token: `Authorization: Bearer <jwt>`, ~15 minutes.
- Refresh token: httpOnly cookie, sent automatically. **Refresh endpoints require
  `credentials: 'include'` and are the reason CORS is an allowlist rather than `*`.**
- Every route is authenticated by default; public routes opt out with `@Public()`.

Getting a `401` is normal and expected — the client refreshes and retries once. Getting a
second `401` means the session is genuinely over.

## Idempotency

`POST /expenses` and `POST /settlements` accept an `Idempotency-Key` header. Replaying a key
within 24 hours returns the original response rather than creating a duplicate. This exists
because a flaky mobile connection retrying a request must not create the same expense twice.

## Rate limiting

Global limits are generous. Auth routes are tight: login, register, password reset and
verification-resend are limited per IP **and** per account, because both credential stuffing
and mailbox flooding are real. `429` responses carry `Retry-After`.

## Versioning and breaking changes

The path carries the major version (`/api/v1`). Within a version:

**Additive changes are free** — a new optional field, a new endpoint, a new enum value the
client can ignore.

**Breaking changes are not**, because the frontend generates its types from our OpenAPI
document. Removing a field, renaming one, tightening validation, or changing a status code
will break the other repo's build.

When you must break something:

1. Add the replacement alongside the old one.
2. Mark the old one `@deprecated` in Swagger.
3. Open the paired issue in Zentro-FE and link it in your PR.
4. Remove the old field only after the frontend has migrated.

## Documenting an endpoint

The OpenAPI document is **generated from decorators** — never hand-edited. Every route needs
`@ApiOperation`, `@ApiResponse` for each status it can return, and DTOs annotated with
`@ApiProperty`. An endpoint that renders badly in Swagger UI is an incomplete endpoint, and
because the client's types come from that document, a missing annotation becomes an `any`
in the frontend.
