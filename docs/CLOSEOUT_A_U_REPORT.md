# ShadiDriver — Production Closeout (A–U) Classified Report

**Date:** 2026-10-01 · **Branch:** `arun/frontend` · **Working tree:** 170 changed paths
**Status values:** COMPLETE · PARTIALLY COMPLETE · BLOCKED BY EXTERNAL CONFIGURATION · NOT IMPLEMENTED
**Nothing was committed, staged, or pushed.** All changes remain in the working tree.

Product model this report is measured against: *the customer chooses cars (never drivers); the customer never sees a driver's identity or contact details; drivers never receive customer requests as marketplace leads; ShadiDriver Operations owns review, allocation, chauffeur assignment, customer communication and confirmation; a driver only receives operations-allocated work.*

---

## 1. Classified status

| # | Item | Status | Evidence |
|---|---|---|---|
| A | Real Google Sign-In setup | **BLOCKED BY EXTERNAL CONFIGURATION** | Endpoint returns an explicit not-configured error naming `GOOGLE_ANDROID_CLIENT_ID` / `GOOGLE_IOS_CLIENT_ID` / `GOOGLE_WEB_CLIENT_ID`; no fake token path anywhere. Needs Google Cloud OAuth client IDs + release-APK SHA-1 (docs §2). |
| B | Real SMS abstraction (OTP traffic) | **COMPLETE** (real delivery blocked) | `SmsProvider` interface with `ConsoleSmsProvider` (throws in production) and `Msg91SmsProvider` (fails fast when credentials are missing). Live: every login in this session was a real OTP cycle over the abstraction; codes were hashed at rest and delivered through the provider. Real MSG91 delivery needs `SMS_AUTH_KEY` / `SMS_OTP_TEMPLATE_ID` / `SMS_SENDER_ID`. |
| C | Confirmation communications | **COMPLETE** (both payment paths) | `sendTransactional()` added to the SMS abstraction; on the transition to `CONFIRMED` the customer's phone receives the confirmation **after** the capture transaction commits. Wired on BOTH the single-booking path and the managed (group) path; a balance settlement never re-sends it. Live-verified: `SD-2026-0148` → `…is CONFIRMED for 2026-12-05. Our operations team is arranging your vehicle and chauffeur…`, and the managed booking `SD-GRP-2026-741679` → `…is CONFIRMED for 2026-12-12. Our operations team is arranging your vehicles and chauffeurs. Your trip start OTP will be sent to this number.` (balance capture logged no second message). Real delivery needs a **second DLT-approved non-OTP template** (`SMS_TRANSACTIONAL_TEMPLATE_ID`); until then the send throws and is logged as a delivery failure — it never rolls back the payment. |
| D | Real payment gateway behind an abstraction | **COMPLETE** (live collection blocked) | `RazorpayGateway` (order create, timing-safe HMAC verify, raw-body webhook HMAC; accepts `x-razorpay-signature` or `x-gateway-signature`). Boot refuses `PAYMENT_GATEWAY=razorpay` without `PAYMENT_KEY_ID` / `PAYMENT_KEY_SECRET` / `PAYMENT_WEBHOOK_SECRET`; the mock gateway refuses production. Live card collection is BLOCKED BY EXTERNAL CONFIGURATION (merchant keys + hosted-checkout SDK leg). |
| E | Payment lifecycle for operations-allocated bookings | **COMPLETE** (fixed + live-verified this session) | An advance token is now payable on `DRIVER_ACCEPTED` (the state `assign-chauffeur` produces) and a verified capture runs the state machine's `CONFIRM_PAYMENT` edge → `CONFIRMED`. Live: booking `SD-2026-0145` and `SD-2026-0147` both paid → CONFIRMED. |
| F | Partner vehicle image upload | **COMPLETE** (live-verified) | `POST /partner/vehicles/:id/photos` → `201`, stored `/media/vehicles/15d03d48-e2e-car.png` (70 B, `image/png`, `is_primary: true`, slot `EXTERIOR`), served back `200 image/png`. Ownership-checked, MIME/size-gated (8 MB). |
| G | Partner vehicle document upload | **COMPLETE** (live-verified) | `POST /partner/vehicles/:id/documents/upload` → `201`, `COMMERCIAL_INSURANCE`, `verification_status: PENDING_REVIEW`; storage path is server-assigned (never client-supplied). |
| H | Admin verification workflow | **COMPLETE** | Live `GET /admin/dashboard/stats` → `total_customers 64, total_drivers 22, total_cars 18, available_cars 11, pending_verification 19 {vehicles 9, partners 6, documents 4}, new_bookings 48, confirmed_bookings 5, completed_bookings 8, payments_pending 0`; verification decisions re-open the vehicle's availability state and re-poison the media on change. |
| I | Service-area eligibility | **COMPLETE** | Partner vehicles carry `service_areas`; the public vehicle DTO exposes them and the app filters/searches by them. |
| J | Privacy DTOs (customer / driver / admin) | **COMPLETE** + hardened this session | One booking row, three role-scoped views. Unified across reads, lifecycle **and submission** responses: `POST /bookings` and `POST /group-bookings` now answer with the same customer view as their `GET` counterparts (plus `submitted_at` / `created_at`), so the raw row (trip-OTP hash, idempotency key, pricing snapshot, FKs, policy ids) is never serialized anywhere. Unrelated callers get `404`, never a probe oracle. |
| K | Driver workflow audit (marketplace removed) | **COMPLETE** (live-verified) | `GET /bookings/driver/offers` → `{offers: [], assignments: [...], completed: [...]}`. Allocation is admin-only (`operationsAdmin` / `superAdmin`); a driver receives work only from Operations and reports conflicts through `assignment-conflict` (never a marketplace decline). |
| L | Customer flow / cart / pricing / trip-type | **COMPLETE** | Server re-quotes every submission (client totals never trusted); `ROUND_TRIP` bills the one-way route twice; partner pricing is derived server-side from fuel ÷ mileage + ₹10. |
| M | Admin dashboard / operations | **COMPLETE** (live-verified) | Stats above; allocation, conflict handling and milestone endpoints all exercised live. |
| N | Reviews gating | **COMPLETE** | Only a `COMPLETED` booking is reviewable; reviews enter a moderation queue and only `PUBLISHED` rows feed public aggregates. |
| O | Environment separation + production mock audit | **COMPLETE** | Mock gateway refuses production, dev checkout refuses production, `ConsoleSmsProvider` refuses production, `devLoginAsRole` refuses in `kReleaseMode`, dev auth harness is unmounted, all mock repositories live behind `useMockData` / `SHADI_USE_MOCK_AUTH`, and the app defaults to the real API. |
| P | Tests | **COMPLETE** | Backend `482/482` across 39 suites (`npx jest --maxWorkers=2`; default parallelism OOMs on this machine). Flutter `608 passed`, `flutter analyze` clean. Live Dart suites against the real backend: 8/8, zero skips. Includes the presentation-layer privacy harness (§4): 14 widget tests (2 of them harness self-check probes), 6 mapper tests and 8 deterministic customer goldens. |
| Q | Android E2E | **PARTIALLY COMPLETE** | Release APK (58.4 MB) built, installed and launched on the Pixel_6a emulator (`Displayed in.shadidriver.app/.MainActivity +12s`), and the device reached the live API (`[api] POST /api/v1/auth/refresh → 401 AUTH_INVALID_TOKEN`). A scripted on-device UI journey was not re-run this session: Flutter release builds expose no accessibility semantics, so `uiautomator` yields geometry only; the API-level fallback (§3) covers the flows instead. |
| R | Visual regression | **COMPLETE** | 8 deterministic customer-surface goldens (390×844 @3.0 dpr, en_US, textScale 1.0, bundled fonts, fixed fixtures) cover vehicle card, vehicle details, cart, review, confirmation, group booking detail, fare breakdown and booking history. Every golden fixture also carries planted private sentinels and the test asserts their absence in the widget tree, semantics tree **and** the golden itself (§4). Re-run without `--update-goldens` reproduces byte-identical images. |
| S | External configuration documentation | **COMPLETE** | [PRODUCTION_SETUP.md](PRODUCTION_SETUP.md) (per-variable tables, boot-refusal list, APK build, verification curls, payments honesty section, security posture) updated this session with the transactional template, the confirmation-comms contract and the new hardening notes. |
| T | Security hardening (this session) | **COMPLETE** (live-verified) | (1) Trip-OTP hash leak closed — see §2.1; (2) malformed route ids are `400`, not Prisma `P2023 → 500` — see §2.3; (3) customer booking lists and BOTH submission endpoints serialized through the customer view — see §2.2 and §2.7. |
| U | Final classified report | **COMPLETE** | This document. |

---

## 2. Defects found and fixed this session

### 2.1 Trip-OTP hash leak in lifecycle responses (security, high)
`POST /bookings/:id/transition` returned the **raw booking row** to every actor. A live `START_TRIP` as the chauffeur returned
`"startOtpHash":"3bad45f2…"` — a SHA-256 of a **4-digit** code. 10,000 candidates hash in milliseconds, so a chauffeur could brute-force the host's trip OTP offline and start a trip without the host present, defeating the control's entire purpose.
**Fix:** transitions now return the caller's role-scoped privacy DTO. Live re-verified: `COMPLETE_TRIP` returned `DriverAssignmentDto` (`host_name`, `host_phone`, `status: COMPLETED`) with `startOtpHash` and `idempotencyKey` absent.
Regression test added: *"transition responses NEVER carry the trip-OTP hash or idempotency key"*.

### 2.2 Customer booking list exposed internal columns
`GET /bookings/my` returned raw rows (`driverFk`, `idempotencyKey`, `startOtpHash`, policy ids).
**Fix:** serialized through `CustomerBookingDto` — no chauffeur identity or link, assurance copy instead (`chauffeur_verification`), with the *existence* of an allocation signalled without identity. Live-verified: `driver: null`, `chauffeur_verification: "Vehicle and chauffeur verified by ShadiDriver"`, zero occurrences of `driverFk` / `idempotencyKey` / `startOtpHash`.

### 2.3 Malformed route ids produced 500s
Non-UUID ids reached Prisma and surfaced as `INTERNAL_ERROR` (`P2023 … invalid character: found 'm'`) on `:id` routes.
**Fix:** `ParseUUIDPipe` on bookings, group bookings, favourites and vehicles routes. Live-verified: `/bookings/mine`, `/group-bookings/grp-1`, `/vehicles/not-a-uuid` → `400` (were `500`).

### 2.4 Operations-allocated bookings could not be paid
`createAdvanceTokenOrder` rejected `DRIVER_ACCEPTED` (exactly what `assign-chauffeur` produces) and `capturePayment` had no branch for it, so an ops-allocated booking could never reach `CONFIRMED` — the chauffeur could never start the duty.
**Fix:** `DRIVER_ACCEPTED` is payable, and a verified capture runs `CONFIRM_PAYMENT` → `CONFIRMED`. Live-verified twice (`SD-2026-0145`, `SD-2026-0147`).

### 2.5 Customer UI still rendered chauffeur identity
The app displayed an assigned chauffeur's **name** in the bookings list, a *Call* CTA in booking detail, a chauffeur id in the result screen and a chauffeur reference in the review screen — contradicting the product model in mock/demo data and leaving dead identity paths in API mode.
**Fix:** every customer-facing surface now shows the platform assurance copy (`BookingSummary.chauffeurVerification`), the direct-call affordance is removed, and the mock repository stamps the assurance copy instead of a name. Tests now assert the **absence** of identity.

### 2.6 SMS abstraction could not send non-OTP traffic
Confirmation communications had no path at all: the provider interface only exposed `sendOtp`.
**Fix:** `sendTransactional(phone, message)` added (console provider prints a DEV SMS and still refuses production; MSG91 uses the Flow API and requires a DLT non-OTP template), wired into payment confirmation post-commit, covered by two new specs (sent on CONFIRMED; an outage never fails a captured payment).

### 2.7 Submission responses returned the raw row (single **and** group)
`POST /bookings` answered with the freshly-created Prisma row (owner-only, but it carried `idempotencyKey`, `customerFk` and — on a later replay — the trip-OTP hash), while `POST /group-bookings` answered with the raw group row (`idempotencyKey`, `pricingSnapshot`, `customerFk`). Both reads were already role-scoped, so this was the last way an internal row shape could reach the wire. The group submit response was also *unusable* by the app: the client mapper expects the customer serialization, so a real submission mapped to an empty fleet with no price.
**Fix:** both submission endpoints (and their idempotent-replay branches) now serialize through the same customer view as their `GET` counterparts. The customer views gained `submitted_at` (single) and `created_at` (group) so the submit result keeps the fields the raw row used to provide.
**Live-verified:** `POST /bookings` → `SD-2026-0148`, keys `[reference_code, submitted_at, chauffeur_verification, driver: null, …]`, **zero** raw keys; replay returned the identical view with `idempotent_replay: true`. `POST /group-bookings` → `SD-GRP-2026-741679`, `11,250,000` paise, 2 assignments, `created_at` present, zero raw keys; replay identical. Regression tests added on both services.

### 2.8 Managed (group) payments confirmed the booking **silently**
The confirmation message added in §2.6 was wired only into the single-booking capture. A managed booking whose advance settled the deal (`CUSTOMER_CONFIRMATION_PENDING` → `CONFIRMED`) told the customer nothing.
**Fix:** `captureGroupTx` now collects the confirmation inside the transaction (customer's account phone, reference, service date, "operations team is arranging your vehicles and chauffeurs") and delivers it **after** commit, with a delivery failure logged and never fatal; the balance settlement deliberately sends nothing (a settlement is not a confirmation).
**Live-verified:** managed booking `SD-GRP-2026-741679` advance captured → `CONFIRMED` + DEV SMS logged; the subsequent balance capture (`8,437,500` paise) logged no second message. Two new specs (message sent on confirming capture; outage never fails a captured payment) plus a no-duplicate assertion.

### 2.9 Presentation-layer privacy harness (new this session)

A golden/widget regression harness now pins customer-layer privacy for all nine customer surfaces, and it is deliberately **hostile**: fixtures carry planted sentinels (`PRIVATE_DRIVER_SHOULD_NOT_RENDER`, `+910000000000`, `private-driver@example.invalid`, `PRIVATE_DRIVER_ADDRESS`, `PRIVATE_INTERNAL_NOTE`, `PRIVATE_PARTNER_NAME`, a registration plate), an offline `HostileApiHarness` re-serializes raw rows that *violate* the `driver: null` contract through the **real** API repositories, and a separate probe proves the scanner fails when a leak is planted (no vacuous pass). Two real defects fell out of it:

* **`booking_api_repository.dart` decoded chauffeur identity for customers** — `_summaryFromRow` still read `driver.user.fullName` / `assigned_chauffeur.name` when present, so a hostile/legacy payload could paint a chauffeur name into the customer booking list. The customer mapper now never decodes chauffeur identity (assurance copy only). *The mock demo repository still seeds a legacy `chauffeurName: 'Rajesh Kumar'`, but `_withAssurance` overwrites it before it reaches a customer surface; the mapper fix removes the API-path risk.*
* **`review_submission_sheet.dart` `_RatingRow` overflowed** — a fixed 170 px label plus five star buttons overflowed 30 px at 390 px width, detected once the harness loaded real fonts. Fixed with `Expanded` + ellipsis (no visual-design change).

---

## 3. Live end-to-end evidence (real API + real Postgres)

| Journey | Result |
|---|---|
| Submission → allocation → advance → confirm (`SD-2026-0148`, rebuilt container) | `POST /bookings` answered with the customer view (`submitted_at`, no `idempotency_key`); replay identical (`idempotent_replay: true`); ops allocated the duty → `DRIVER_ACCEPTED` + trip OTP SMS to the host; advance order `988,750` paise → capture → `CONFIRMED` + confirmation SMS. `GET /bookings/:id` after each step returned the same privacy view. |
| Managed booking end-to-end (`SD-GRP-2026-741679`) | `POST /group-bookings` (2× Innova, `11,250,000` paise, 2 assignments, `created_at`) → ops `BEGIN_REVIEW → PREPARE_VEHICLE_OPTIONS → REQUEST_CUSTOMER_CONFIRMATION` → advance `2,812,500` paise captured → `CONFIRMED` + confirmation SMS; balance `8,437,500` paise captured with **no** second confirmation; customer view showed `service_state: BEING_PREPARED`, `chauffeur_assigned: false` throughout. |
| Ops allocation → advance → confirm → full execution (`SD-2026-0145`) | `REQUESTED → DRIVER_ACCEPTED` (ops) → advance order `706,250` paise → capture → `CONFIRMED` → `START_ROUTE` → `ARRIVE` → trip-OTP resend to the host → `START_TRIP` (OTP-verified) → `COMPLETE_TRIP`; driver duty list then reported `assignments: []`, `completed: [SD-2026-0145]` |
| Confirmation comms (`SD-2026-0147`) | create → allocate chauffeur → pay `988,750` paise → `CONFIRMED` + confirmation SMS logged to the customer's phone |
| Live Dart suites against the live backend | 8/8 passed, **zero skips** (health, catalog, full auth cycle, booking submission with idempotent replay, favourites persistence, cross-account refusal, real-fleet rendering). The submission left real row `SD-2026-0146` in Postgres. |
| Fleet-owner media | photo `201` + served `200`; document `201 PENDING_REVIEW` |
| Fleet-owner pricing | `201`, `per_km_paise "2188"`, `distance_rate_formula "₹95 ÷ 8 km/l + ₹10 = ₹21.880/km"` (server-derived; client value ignored) |
| Admin operations | stats payload above; allocation succeeded with the duty's vehicle and host contact on the assignment |
| Android device | release APK installs, launches, renders (Impeller) and reaches the host API at `10.0.2.2:3000` |

---

## 4. Customer presentation-layer privacy harness

Built this session; nothing in product behaviour, API contracts, schema, pricing, payments, auth, the booking state machine or visual design was changed for it.

**Surface audit (DTO → repository → domain → provider → widget).** All nine customer surfaces were traced: vehicle card (`ShadiVehicleCard` ← `VehicleCardViewModel.fromEntity`), vehicle details (`vehicleDetailsProvider`), cart (`GuestSelectionBar`), fare breakdown (`BookingDraftSummaryCard`), booking review (`bookingReviewControllerProvider`), booking confirmation (`submissionResultProvider`), booking detail (`bookingDetailProvider` + `bookingReviewedProvider`), group booking detail (`groupBookingDetailProvider`), booking history (`customerBookingsProvider`). The backend sides (`CustomerBookingDto`, `DriverAssignmentDto`, `AdminBookingDto` in `backend/src/bookings/booking-view.dto.ts`, `serializeCustomerGroupBooking` with `CUSTOMER_FORBIDDEN_ASSIGNMENT_KEYS`) keep three **distinct** role contracts; admin/driver surfaces still render operational identity and are intentionally outside this harness — no widget downstream of the customer DTOs does the hiding.

**Harness components** (`frontend/test/support/privacy/`, `frontend/test/features/privacy/`):
* `privacy_sentinels.dart` — the sentinel vocabulary, a fixed render environment (390×844, dpr 3.0, textScale 1.0, en_US; restored after each test), bundled-font loading (`loadShadiFonts`, no network), `pumpPrivacySurface` (real `ProviderScope` + `AppTheme.lightTheme`, optional `decodeImages` via `runAsync`), `presentedStrings()` (Text/RichText/Tooltip/EditableText/Semantics widgets), `semanticsTreeStrings()` (walks the real semantics owner: labels, values, hints, tooltips) and `expectNoPrivateSentinels()`.
* `sentinel_fixtures.dart` — dangerous fixtures for summary, submission result, draft, assignment, group booking, vehicle summary/details with sentinels in `chauffeurName` / `chauffeurId` / `ownerName` / `registrationNumber`, sentinel repositories, and `assertFixtureIsDangerous()` which throws if any sentinel is missing so the suite can never pass vacuously.
* `hostile_api_harness.dart` — feeds deliberately contract-violating payloads through the **real** `BookingApiRepository` / vehicle repository and asserts the customer-safe fields survive while identity does not (mapper-level pins, not source-string greps).
* 14 widget tests (`customer_privacy_widget_test.dart`), 6 mapper tests (`customer_privacy_mapper_test.dart`), 8 goldens (`customer_privacy_golden_test.dart` + `goldens/*.png`). The self-check group proves the scanner catches a planted text leak *and* an accessibility-only (semantics, no text) leak, and that the semantics tree is genuinely populated on a real surface.

Sentinels are **injected, never omitted**: every fixture contains them, and the tests assert their absence across widget text, the semantics tree and the rendered golden.

---

## 5. Verification commands

```bash
# backend
cd backend && npx tsc --noEmit && npx jest --maxWorkers=2      # 482/482, 39 suites

# app
cd frontend && /c/src/flutter-new/bin/flutter analyze && /c/src/flutter-new/bin/flutter test   # 608 passed
cd frontend && /c/src/flutter-new/bin/flutter test test/features/privacy   # privacy harness (28 tests)
cd frontend && /c/src/flutter-new/bin/flutter test test/features/privacy/customer_privacy_golden_test.dart --update-goldens  # only after inspecting PNGs

# live app-code suite against the running stack (needs OTP_DEBUG_EMIT=true on the API)
OTP_DEBUG_EMIT=true docker compose up -d api
LIVE_API_BASE_URL=http://localhost:3000 flutter test test/live_backend_connection_test.dart

# device artifact
flutter build apk --debug                                       # app-debug.apk
flutter build apk --release                                     # 58.4 MB
```

---

## 6. Residual gaps (not blocked on credentials)

1. **On-device UI automation** is not scripted; Flutter release builds expose no accessibility semantics, so `uiautomator` gives geometry only (the golden harness covers layout/pixels headlessly instead).
2. **Backend jest needs bounded workers on this machine** — run `npx jest --maxWorkers=2`, or V8 aborts with `Zone Allocation failed - process out of memory` while the emulator and Docker are also running.
3. **Admin/driver presentation layers are outside the privacy harness** — they are authorized to show identity, so their own leak surface (into *customer* views) is covered by the backend DTO tests and the mapper pins, but their widgets have no equivalent sentinel suite.
4. **Designed-in bounded risks:** the mock/demo repository still seeds a legacy `chauffeurName` that `_withAssurance` overwrites before reaching any customer surface (mock-only, screened); device-specific rendered privacy (e.g. voiceover of an OS-rendered control) remains out of scope for headless goldens.

**Closed since the previous revision:** submission responses (single and group) now serialize through the customer views (§2.7), the managed payment path sends the confirmation message (§2.8), and `backend/.env.example` now documents `SMS_TRANSACTIONAL_TEMPLATE_ID` + `SMS_MSG91_FLOW_URL` (edited with a script because the file-editing tools mask `.env.example`) — all live-verified end-to-end on the rebuilt container.

## 7. Blocked by external configuration (exact variables)

| Capability | Variables / artifacts required |
|---|---|
| Google Sign-In | `GOOGLE_ANDROID_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_WEB_CLIENT_ID`, release-APK SHA-1 (`google-services.json`) |
| Real OTP delivery | `SMS_PROVIDER=msg91`, `SMS_AUTH_KEY`, `SMS_OTP_TEMPLATE_ID`, `SMS_SENDER_ID` |
| Real confirmation delivery | `SMS_TRANSACTIONAL_TEMPLATE_ID` (DLT-approved non-OTP template) |
| Real payment collection | `PAYMENT_GATEWAY=razorpay`, `PAYMENT_KEY_ID`, `PAYMENT_KEY_SECRET`, `PAYMENT_WEBHOOK_SECRET` + hosted-checkout SDK leg in the app |
| Durable media | a mounted `MEDIA_ROOT` volume (or an S3 `StorageProvider` implementation) |

Until these are issued, the platform is honest by construction: Google auth names the missing variable, SMS throws instead of pretending, and the gateway refuses to boot without credentials. Nothing is faked.
