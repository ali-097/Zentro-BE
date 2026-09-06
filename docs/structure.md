# File structure

Where everything lives, and where to put new things.

## The tree

```
zentro-be/
├── src/
│   ├── main.ts                  Bootstrap: global pipes, filters, interceptors,
│   │                            helmet, CORS, Swagger. Read this first.
│   ├── app.module.ts            Root module. Wires config, database, feature modules.
│   │
│   ├── config/                  Typed configuration, validated once at boot
│   │   ├── configuration.ts       Groups env vars into typed objects
│   │   ├── env.validation.ts      Schema. Missing/invalid var ⇒ the app refuses to start
│   │   └── config.types.ts
│   │
│   ├── common/                  Cross-cutting. Imported by features; imports no feature.
│   │   ├── decorators/            @Public, @CurrentUser, @Roles
│   │   ├── guards/                JwtAuthGuard, GroupMemberGuard, GroupAdminGuard
│   │   ├── filters/               AllExceptionsFilter — the one error envelope
│   │   ├── interceptors/          Serialization, request logging
│   │   ├── pipes/                 ParseUuidPipe and friends
│   │   ├── errors/                Domain exceptions (GroupNotFoundError, ...)
│   │   ├── money/                 ★ Minor-unit arithmetic, split allocation, rounding
│   │   ├── pagination/            Cursor encode/decode, page DTOs
│   │   └── types/
│   │
│   ├── database/
│   │   ├── data-source.ts         TypeORM DataSource used by the CLI. synchronize: false.
│   │   ├── migrations/            Timestamped, append-only. Never edit a merged one.
│   │   └── seeds/                 Demo data for local development
│   │
│   └── modules/                 One folder per aggregate
│       ├── auth/
│       ├── users/
│       ├── groups/
│       ├── expenses/
│       ├── settlements/
│       ├── attachments/
│       ├── currencies/
│       ├── activity/
│       └── health/
│
├── test/                        Integration and e2e specs + fixtures/factories
├── docs/                        You are here
├── bruno/                       Committed API request collection (git-diffable)
└── openapi.json                 Generated on merge to main. The frontend's contract.
```

`src/common/money/` is starred because it is the highest-consequence code in the repo. If
you find yourself writing arithmetic on an amount anywhere else, it belongs there instead.

## Inside a module

Every module looks the same. Consistency here is worth more than local cleverness:

```
modules/expenses/
├── expenses.module.ts
├── expenses.controller.ts       HTTP only. Routes, DTOs, guards, Swagger.
├── expenses.service.ts          All business logic. HTTP-blind.
├── expenses.repository.ts       Custom queries (balances, feeds). Optional.
├── dto/
│   ├── create-expense.dto.ts      Request — every field class-validator decorated
│   ├── update-expense.dto.ts
│   ├── query-expenses.dto.ts      Query params are input too: validate them
│   └── expense.response.dto.ts    Response shape. Never an entity.
├── entities/
│   ├── expense.entity.ts
│   ├── expense-split.entity.ts
│   └── expense-payer.entity.ts
├── strategies/                  Split calculators: equal, exact, percentage, shares
└── expenses.service.spec.ts     Unit tests live beside the code they test
```

## Where do I put X?

| I'm adding... | It goes in |
|---|---|
| A new endpoint | The relevant `modules/<aggregate>/` — controller + service + DTOs |
| A new table | `modules/<aggregate>/entities/` **plus** a migration in `database/migrations/` |
| Logic two modules need | `src/common/` — **not** an import across feature folders |
| Anything that does arithmetic on money | `src/common/money/` |
| A new environment variable | `.env.example`, `config/configuration.ts`, **and** `config/env.validation.ts` |
| A reusable authorization rule | `common/guards/` |
| A new error the client should distinguish | `common/errors/` + a `type` URI in [api/README.md](./api/README.md) |
| A unit test | Beside the file, as `*.spec.ts` |
| An integration test | `test/`, as `*.e2e-spec.ts` |
| A decision worth remembering | `docs/adr/` |

## Rules the structure encodes

1. **`common/` never imports from `modules/`.** If it needs to, the dependency is backwards
   and the logic belongs in a service.
2. **Modules don't import each other's internals.** Import the other module's *service* via
   its module export, never reach into its repository or entities directly.
3. **One aggregate per module.** `expenses` owns expenses, payers and splits, because those
   three are meaningless apart. Groups and expenses are separate.
4. **Tests live beside unit-tested code, and in `test/` when they need a database.** The
   split is about whether Postgres is required, not about the kind of assertion.
5. **Nothing business-related lives in `main.ts`.** It wires the application and stops.
