# ShadiDriver Backend

NestJS 11 + PostgreSQL 16 (PostGIS) + Prisma 6 + Redis modular-monolith API for the
ShadiDriver wedding-chauffeur marketplace. Server-authoritative for booking state,
pricing, availability, and authorization.

> **Status: Phase 1 complete** — foundation, config, database schema/migrations,
> auth (OTP + JWT + refresh rotation), role guards, health probes, Swagger,
> booking state-machine policy (tested). Domain modules (bookings, availability,
> fleet, pricing, payments, admin) land in Phases 2–9 per `docs/DEVELOPMENT_PLAN.md`.

## 1. Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Node.js | ≥ 20 (24 recommended) | |
| npm | ≥ 10 | |
| Docker + Docker Compose | any recent | for Postgres/Redis; **not required** to run the API with mocks |

> If Flutter tests fail locally with an "Application Control" error, move the Flutter
> SDK out of `Downloads` — Windows blocks executables there.

## 2. Environment variables

```bash
cp .env.example .env
```

All values are read from env — never hard-code secrets (see `src/config/configuration.ts`).
In production, `JWT_*` secrets and `DATABASE_URL` **must** be provided or startup fails
by design. Development falls back to clearly-labeled dev-only defaults.

Key variables: `DATABASE_URL`, `REDIS_URL` (optional — API degrades gracefully),
`JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `JWT_ACCESS_TTL_SECONDS` (default 900),
`OTP_DEBUG_LOG` (dev only; hard-disabled in production), `THROTTLE_*`.

## 3. Start infrastructure (Docker)

```bash
docker compose up -d postgres redis
```

PostGIS is used for future geo queries; plain Postgres works for Phase 1–5 flows.

## 4. Database migration

```bash
npm run prisma:generate        # generate the typed client
npm run prisma:migrate:dev     # dev: creates/applies migrations (needs DB)
# or in CI/prod:
npm run prisma:migrate         # prisma migrate deploy (applies committed migrations)
```

The initial migration (`prisma/migrations/0001_init/migration.sql`) is committed and
reproducible via `npx prisma migrate diff --from-empty --to-schema-datamodel prisma/schema.prisma --script`.

> Legacy note: `infra/migrations/0001_init.sql` was the pre-backend reference schema
> (Supabase-style RLS). Prisma now owns migrations; the legacy file stays for reference.
> Prisma adds: `group_bookings`, `vehicle_assignments`, `refresh_tokens`, `otp_codes`,
> `vehicle_types` — gaps identified during the audit.

## 5. Seed

```bash
npm run db:seed
```

Seeds Delhi NCR demo data (synthetic phones `+919810000001…15`): 1 customer,
5 chauffeurs, 1 fleet owner (10 vehicles / 4 types), 2 admins, categories, addons,
pricing rules, default booking policy, and one `REQUESTED` sample booking
(reference `SD-2026-0101`). No real credentials are included.

## 6. Run the backend

```bash
npm run start:dev      # watch mode, http://localhost:3000
npm run start:prod     # after npm run build
```

Or the full stack: `docker compose up -d --build`.

## 7. Run tests

```bash
npm test               # unit tests (state machine, roles, OTP, tokens)
npm run test:cov       # with coverage
npm run lint:check     # eslint (flat config, strict)
npm run typecheck      # tsc --noEmit (strict)
```

## 8. Swagger / OpenAPI

Interactive docs: **http://localhost:3000/api/docs** (enabled when `ENABLE_SWAGGER=true`).

## 9. Frontend API configuration

The Flutter app (`frontend/`) reads `--dart-define` values:

```bash
flutter run \
  --dart-define=SHADI_API_BASE_URL=http://localhost:3000 \
  --dart-define=SHADI_USE_MOCK_AUTH=true
```

Until Phase 10 lands, the app continues to use mock repositories (`useMockData=true`).
The existing `core/network/ApiClient` (Dio + auth/correlation/logging interceptors)
is the integration point — screens never talk HTTP directly (ADR-005).

## 10. Troubleshooting

| Symptom | Fix |
|---|---|
| `P1001 can't reach database` | Start `docker compose up -d postgres`; check `DATABASE_URL`. |
| `Environment variable not found: DATABASE_URL` (prisma CLI) | `cp .env.example .env`. |
| `ERESOLVE` on npm install | Use the committed `package.json` versions (Nest 11 line is CJS-compatible with Jest/ts-jest). |
| Nest 12 note | Nest 12 ships ESM-only and is incompatible with ts-jest 29; the project pins Nest 11 until the Jest ESM story settles. |
| Port 3000 busy | `BACKEND_PORT=3001 docker compose up` (compose) or set `PORT`. |
| OTP not arriving | Dev only: codes are logged to the console (`[DEV-OTP] ...`) when `OTP_DEBUG_LOG=true`. |
| Redis down | Non-fatal; API runs without cache until a feature requires it. |

## API surface (Phase 1)

| Method | Path | Auth |
|--------|------|------|
| POST | `/api/v1/auth/otp/request` | public (rate-limited) |
| POST | `/api/v1/auth/signup` | public (customer/driver only) |
| POST | `/api/v1/auth/otp/verify` | public |
| POST | `/api/v1/auth/refresh` | public (rotating refresh token) |
| POST | `/api/v1/auth/logout` | public (revoke token) / authenticated (revoke all) |
| GET  | `/api/v1/auth/me` | bearer |
| GET  | `/health`, `/health/ready` | public |

Errors use the documented envelope `{ success:false, error:{ code, message, details } }`
with codes from `docs/API_CONTRACTS.md` §9. Successes wrap as `{ success:true, data, meta? }`.
