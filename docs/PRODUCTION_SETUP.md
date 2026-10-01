# ShadiDriver — Production Setup (External Configuration)

Everything ShadiDriver needs from the **outside world** to run as a real
product, with the exact environment variables and platform steps. Nothing in
this file is faked: where a credential is missing, the affected feature fails
fast with an explicit error instead of silently pretending to work.

Companion file: [`backend/.env.example`](../backend/.env.example) (copy to
`backend/.env`).

---

## 1. Status at a glance

| Capability | Backend integration | App integration | Blocked on |
|---|---|---|---|
| Phone + OTP login | Complete (crypto OTP, hashed at rest, rate-limited) | Complete | MSG91 credentials for real SMS delivery |
| Google Sign-In | Complete (explicit not-configured errors) | Complete (platform channels) | Google Cloud OAuth client IDs + APK SHA-1 |
| Payments | Complete (Razorpay adapter: orders, HMAC verify, webhook) | Dev checkout only — see §6 | Razorpay live keys + hosted-checkout SDK wiring |
| SMS — OTP traffic | Complete (provider abstraction, msg91/console) | Complete | MSG91 account |
| SMS — booking confirmations | Complete (transactional sends on CONFIRMED, post-commit, on BOTH the single and managed payment paths) | In-app confirmation UI only | MSG91 account + `SMS_TRANSACTIONAL_TEMPLATE_ID` (DLT non-OTP template) |
| Vehicle/document uploads | Complete (multipart, managed local storage) | Complete | Durable storage volume (or S3 adapter) |
| Pricing (fuel ÷ mileage + ₹10) | Complete (server-derived, partner inputs only) | Complete | — |
| Operations allocation workflow | Complete (assign/conflict/milestones) | Complete | — |

---

## 2. Environment variables (backend)

Set these in `backend/.env` (see `.env.example` for the full annotated list).

### Required always
| Variable | Notes |
|---|---|
| `DATABASE_URL` | PostgreSQL 16 (+ PostGIS). `docker compose up -d` provisions the dev instance. |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | Generate: `openssl rand -base64 48`. **Never** ship the dev placeholders. |
| `CORS_ORIGINS` | Comma-separated allowed origins for the web/app origin. |
| `NODE_ENV=production` | Enables every production guard below. |

### Google Sign-In (BLOCKED BY EXTERNAL CONFIGURATION until issued)
| Variable | Where it comes from |
|---|---|
| `GOOGLE_ANDROID_CLIENT_ID` | Google Cloud Console → Credentials → OAuth client ID (Android), package `com.shadidriver.app` + **signing SHA-1** of the release APK (`./gradlew signingReport` or `keytool -list -v -keystore release.jks`). |
| `GOOGLE_IOS_CLIENT_ID` | Same console, iOS client ID (bundle id `com.shadidriver.app`). |
| `GOOGLE_WEB_CLIENT_ID` | Web client ID (used by the backend to verify ID tokens). |

The Android app also needs `google-services.json` from the same Firebase/Google
project placed at `frontend/android/app/google-services.json`. Until every
`GOOGLE_*_CLIENT_ID` is set, `POST /auth/google` returns an explicit
"Google sign-in is not configured" error naming the missing variable — it
never accepts a fabricated identity.

### SMS OTP (BLOCKED BY EXTERNAL CONFIGURATION until MSG91 account exists)
| Variable | Notes |
|---|---|
| `SMS_PROVIDER` | `msg91` in production (`console` throws at boot when `NODE_ENV=production`). |
| `SMS_AUTH_KEY` | MSG91 auth key. |
| `SMS_OTP_TEMPLATE_ID` | Pre-approved OTP template. |
| `SMS_SENDER_ID` | Registered 6-letter DLT sender ID (India). |
| `SMS_MSG91_BASE_URL` | Default `https://control.msg91.com/api`. |
| `SMS_TRANSACTIONAL_TEMPLATE_ID` | **Second, non-OTP DLT template** — Indian regulation forbids sending booking-confirmation traffic through an OTP template. Used by `sendTransactional()` on booking CONFIRMED (mapped to MSG91 `VAR1`). Until it is set, confirmation sends throw and are logged as delivery failures; the captured payment and the CONFIRMED state are never rolled back. |
| `SMS_MSG91_FLOW_URL` | Default `https://control.msg91.com/api/v5/flow`. |
| `OTP_DEBUG_LOG=false` | Console OTP logging is development-only. |
| `OTP_DEBUG_EMIT` | Unset in production (used only by the live E2E harness). In `docker-compose.yml` it is passed through as `${OTP_DEBUG_EMIT:-false}` so the live Dart suite can run locally. |

### Payments (BLOCKED BY EXTERNAL CONFIGURATION until Razorpay account exists)
| Variable | Notes |
|---|---|
| `PAYMENT_GATEWAY=razorpay` | `mock` refuses to boot when `NODE_ENV=production`. |
| `PAYMENT_KEY_ID` / `PAYMENT_KEY_SECRET` | Razorpay dashboard → Settings → API keys (use `rzp_live_*` for production). |
| `PAYMENT_WEBHOOK_SECRET` | Razorpay dashboard → Webhooks → secret; verified as HMAC-SHA256 over the **raw body** (`x-razorpay-signature`, also accepted as `x-gateway-signature`) on `POST /payments/webhook`. |
| `PAYMENT_API_BASE_URL` | Default `https://api.razorpay.com/v1`. |

The backend adapter refuses to construct without all three credentials, so a
misconfigured production deployment fails at boot rather than at first
checkout.

### Media / uploads
| Variable | Notes |
|---|---|
| `MEDIA_ROOT` | Absolute directory for `LocalManagedStorage` uploads (photos ≤ 8 MB image MIME types, documents ≤ 12 MB). Served at `/media/*`. Default: `<cwd>/public/media`. Mount a durable volume (or swap in an S3 `StorageProvider`). |

---

## 3. Database migrations

```bash
cd backend
npx prisma migrate deploy      # applies committed migrations, incl.
                               # 20260930200000_pricing_fuel_mileage_inputs
npx prisma generate
```

Seeded development accounts (dev only): admin `+9198100000011`,
driver `+919810000002`, fleet owner `+9198100000013`.

---

## 4. Backend boot checklist

```bash
cd backend
npm run build
NODE_ENV=production node dist/main.js   # or docker compose up -d --build api
```

Expected refusals when misconfigured (these are features, not bugs):

- `SMS_PROVIDER=console` + production → throws naming `SMS_PROVIDER=msg91`.
- `PAYMENT_GATEWAY=mock` + production → throws.
- `PAYMENT_GATEWAY=razorpay` + missing keys → throws naming
  `PAYMENT_KEY_ID`, `PAYMENT_KEY_SECRET`, `PAYMENT_WEBHOOK_SECRET`.
- Google endpoints → explicit not-configured error naming missing
  `GOOGLE_*_CLIENT_ID`.
- `POST /payments/dev/checkout` → 400 "Simulated checkout is not available in production."

---

## 5. Frontend (APK) build

```bash
cd frontend
flutter pub get
flutter build apk --release \
  --dart-define=SHADI_API_BASE_URL=https://api.yourdomain.com
# do NOT set SHADI_USE_MOCK_AUTH — mock repositories exist only for
# offline UI development and automated tests.
```

- Android emulator reachability: `--dart-define=SHADI_API_BASE_URL=http://10.0.2.2:3000`.
- Release signing: configure `android/key.properties` + release keystore; the
  keystore's SHA-1 is what must be registered on the Google Android client ID
  (§2).
- Google: drop the Firebase/Google `google-services.json` into
  `android/app/` before building (external credential — see §2).

---

## 6. Payments: what is real today

- **Complete (real):** Razorpay order creation, server-side HMAC signature
  verification (timing-safe), webhook ingestion with raw-body HMAC, amount
  always taken from the booking row — the client can never mark a payment
  successful.
- **Development pathway (explicitly dev-gated):** the app's
  `processGatewayCheckout` calls `POST /payments/dev/checkout`, which the
  server refuses when `NODE_ENV=production`.- **Operations-allocated bookings:** an advance token is payable on
  `REQUESTED`, `PAYMENT_PENDING`, `PAYMENT_FAILED`, `CONFIRMED` **and
  `DRIVER_ACCEPTED`** (the state `assign-chauffeur` produces). A verified
  capture on a `DRIVER_ACCEPTED` booking runs the state machine's
  `CONFIRM_PAYMENT` edge, moving it to `CONFIRMED` so the chauffeur can begin
  execution (`START_ROUTE → ARRIVE → START_TRIP → COMPLETE_TRIP`). Verified
  live end-to-end.
- **Confirmation communications:** on the transition to `CONFIRMED` the
  customer's phone receives a transactional message (reference, service date,
  "operations is arranging your vehicle and chauffeur" — never a chauffeur
  identity). Both payment paths are wired: the single-booking advance capture
  and the managed (group) advance capture that settles the deal
  (`CUSTOMER_CONFIRMATION_PENDING → CONFIRMED`); a group balance settlement
  deliberately sends nothing. It is sent **after** the capture transaction
  commits: an SMS outage is logged and can never fail or roll back the
  payment.
- **Pending external config + SDK wiring:** the production hosted-checkout leg
  (Razorpay checkout SDK in the app → `POST /payments/verify` with the
gateway-issued signature). Until the live keys exist and the SDK leg is
  wired, payment collection is classified **PARTIALLY COMPLETE**, not complete.

---

## 7. Production verification checklist

```bash
# Health / auth
curl -s $API/api/v1/health
curl -s -X POST $API/api/v1/auth/otp/request -H 'content-type: application/json' \
  -d '{"phoneNumber":"+919810000002"}'

# Google (should name a missing GOOGLE_* var until configured)
curl -s -X POST $API/api/v1/auth/google -H 'content-type: application/json' \
  -d '{"idToken":"x"}'

# Operations stats (admin JWT required)
curl -s $API/api/v1/admin/dashboard/stats -H "authorization: Bearer $ADMIN_JWT"

# Driver duty wire (driver JWT) — offers must be [] and duties under `assignments`
curl -s $API/api/v1/bookings/driver/offers -H "authorization: Bearer $DRIVER_JWT"

# Payments (should refuse in production without Razorpay config)
curl -s -X POST $API/api/v1/payments/dev/checkout -H 'content-type: application/json' -d '{}'
```

---

## 8. Security posture for production

- `NODE_ENV=production`, `OTP_DEBUG_LOG=false`, `OTP_DEBUG_EMIT` unset.
- Regenerate `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET`.
- `ENABLE_SWAGGER=false` on internet-facing deployments.
- TLS terminates at the reverse proxy; keep `CORS_ORIGINS` minimal.
- `/media` and `/payments/webhook` are the only intentionally public write/read
  paths besides auth; webhook stays HMAC-verified.
- Booking reads are role-scoped (customer / assigned driver / admin) and
  return 404 to unrelated callers — no enumerable booking IDs.
- **Lifecycle responses are role-scoped too:** transitions return the same
  privacy DTO as reads (`CustomerBookingDto` / `DriverAssignmentDto` /
  `AdminBookingDto`). The raw booking row is never serialized — it carries the
  trip-OTP **hash**, which a 4-digit code space makes brute-forceable offline.
  The chauffeur enters the host's code and must never receive the hash.
- **Route ids are UUID-validated** (`ParseUUIDPipe`) on bookings, group
  bookings, favourites and vehicles: a malformed id is a `400`, not a Prisma
  `P2023 → 500` (which also leaked a stack trace to the client).
- **Customer booking lists** (`GET /bookings/my`) are serialized through the
  customer view: no `driverFk`, no chauffeur identity/phone, no idempotency
  key, no OTP hash — the customer sees the platform assurance copy
  ("Vehicle and chauffeur verified by ShadiDriver") instead of a person.
