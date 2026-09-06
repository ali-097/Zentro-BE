---
name: add-endpoint
description: Scaffold a new REST endpoint in the Zentro API - controller route, service method, request/response DTOs, authorization guard, Swagger annotations and tests - following this repo's conventions. Use when adding any new route or resource.
---

# Add an endpoint

Follow this in order. Do not skip the authorization or test steps — they are the two most
commonly omitted and the two that matter most.

## 1. Establish the shape before writing code

Confirm, from the issue or by asking:

- **Route and verb.** Plural noun, verb carries the action: `POST /groups/:groupId/members`,
  never `POST /groups/:groupId/addMember`. Nesting stops at one level.
- **Who may call it.** Any authenticated user? A group member? A group admin? This decides
  the guard, and there is no safe default.
- **Request and response shapes**, in camelCase. Money is always `{ amountMinor, currency }`.
- **Which module owns it.** The aggregate, not the URL. An endpoint about expenses belongs in
  `modules/expenses/` even if its path starts `/groups/:groupId/`.

If the route is group-scoped and the issue does not say who may call it, **ask** rather than
guessing. Guessing here produces a security bug that passes review.

## 2. Request DTO — `dto/<action>-<resource>.dto.ts`

Every property gets a `class-validator` decorator and an `@ApiProperty`. A property without
a validator is rejected at runtime by `forbidNonWhitelisted`, which surfaces as a confusing
400 rather than an error you can trace.

```ts
export class CreateExpenseDto {
  @ApiProperty({ example: 'Dinner' })
  @IsString()
  @Length(1, 200)
  description!: string;

  @ApiProperty({ example: 1230, description: 'Amount in minor units' })
  @IsInt()
  @IsPositive()
  amountMinor!: number;

  @ApiProperty({ example: 'EUR' })
  @IsISO4217CurrencyCode()
  currency!: string;
}
```

Query parameters are input too — give them a DTO. Sort fields come from an allowlist enum,
never a free string.

## 3. Response DTO — `dto/<resource>.response.dto.ts`

**Never return an entity.** Entities carry `password_hash`, `token_hash` and `deleted_at`.
Write an explicit response class with `@ApiProperty` on each field and map to it.

Collections are wrapped: `{ data: [...], pageInfo: { nextCursor, hasNextPage } }`. Never a
bare array — there would be nowhere to add pagination later without breaking clients.

## 4. Service method

All business logic lives here. The service must not import `Request`, `Response`,
`HttpException` or anything else HTTP-shaped — pass the acting user id in as an argument.

- Throw domain errors from `common/errors/` (`GroupNotFoundError`), never `NotFoundException`.
- **Scope the query by membership**, even though a guard already checked. Guards get dropped
  in refactors; a scoped query still fails safe.
- Anything writing more than one table runs in a transaction.
- Any arithmetic on an amount uses `common/money/`. Never divide an amount inline.

## 5. Controller route

Thin. Route decorator, guards, DTO, Swagger, delegate, map to the response DTO.

```ts
@Post(':groupId/expenses')
@UseGuards(GroupMemberGuard)
@ApiOperation({ summary: 'Create an expense in a group' })
@ApiResponse({ status: 201, type: ExpenseResponseDto })
@ApiResponse({ status: 404, description: 'Group not found or caller is not a member' })
@ApiResponse({ status: 422, description: 'Splits do not sum to the total' })
async create(
  @Param('groupId', ParseUUIDPipe) groupId: string,
  @CurrentUser() userId: string,
  @Body() dto: CreateExpenseDto,
): Promise<ExpenseResponseDto> {
  return toExpenseResponse(await this.expenses.create(groupId, userId, dto));
}
```

Swagger annotations are not optional: the frontend generates its types from this document,
so a missing `type:` becomes an `any` in the other repo.

## 6. Tests

Unit-test the service logic. Then, in `test/`, cover **all four**:

1. Authorized caller succeeds
2. No token → 401
3. **Authenticated non-member → 404** (not 403 — 403 confirms the resource exists)
4. Invalid body → 400, or semantically invalid → 422

Case 3 is mandatory for every group-scoped route. Reviewers block PRs without it.

## 7. Verify

```bash
npm run lint && npm run typecheck && npm test
```

Then check the route renders correctly in Swagger UI at `/docs`. If it looks wrong there, it
will generate a wrong client type.

## Reference

- [docs/api/README.md](../../../docs/api/README.md) — status codes, errors, pagination
- [docs/security.md](../../../docs/security.md) — the authorization rules
- [docs/conventions.md](../../../docs/conventions.md) — naming, errors, queries
