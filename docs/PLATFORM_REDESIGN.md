# ShadiDriver — Canonical Platform Model (Vehicle-First, Operations-Managed)

Status: **authoritative design reference**. `docs/API_CONTRACTS.md` remains the wire
contract; when the two disagree about field names, this document wins on *domain
semantics* and the running backend wins on *literal names*.

This document replaces the driver-marketplace assumptions baked into the first
generation of the codebase. Read section 2 before touching anything.

---

## 1. Product model (one paragraph)

The customer selects **vehicles**, never drivers. The customer submits a **Booking
Request**. ShadiDriver Operations reviews it, sources vehicles from one or many
partners, assigns chauffeurs internally, prices it, contacts the customer, and only
then is a booking **CONFIRMED**. Chauffeur and partner identity are internal
operational data and must never reach a customer-facing response.

---

## 2. Obsolete assumptions found in the current codebase

Each entry is a concrete, evidenced defect — not a style preference.

| # | Where | Obsolete assumption | Evidence | Required correction |
|---|-------|--------------------|----------|---------------------|
| O1 | `frontend/lib/app/router/route_guards.dart` | Auth is enforced for the whole customer portal; a guest is bounced to `/auth` | `ShadiRouteGuard(enforceAuth)` + every customer shell route sits behind `/customer` | Home, Search, Search Results, Vehicle Details must be reachable signed-out |
| O2 | `backend/src/vehicles/vehicles.service.ts` | Driver identity is part of the public catalog | `searchVehicles()` returns `chauffeur_name`, `chauffeur_id` on a `@Public()` endpoint | Public DTO returns `has_verified_chauffeur: boolean` only |
| O3 | `backend/src/vehicles/vehicles.service.ts` | Chauffeur bio, avatar (personal photo), duty status, partner company name and document statuses are public | `getVehicleById()` returns `chauffeur{full_name,avatar_url,bio,duty_status}` + `owner.company_name` + `documents[]` | Public detail DTO exposes vehicle facts + verification badge only |
| O4 | `frontend/lib/features/vehicles/data/vehicle_api_repository.dart` | Trust flag derived from leaked identity | `hasVerifiedChauffeur: json['chauffeur_id'] != null` | Consume the explicit `has_verified_chauffeur` flag |
| O5 | `frontend/lib/features/drivers/presentation/chauffeur_profile_screen.dart` + `/customer/chauffeurs/:chauffeurId` route | Customer can browse a chauffeur profile | `VehicleDetails.chauffeurId` feeds `customerChauffeurProfilePath` | Remove from customer surfaces; replace with a ShadiDriver trust statement |
| O6 | `frontend/lib/features/vehicles/data/vehicle_api_repository.dart` | Client invents prices | `ceremonialAddons` hardcodes ₹3500/₹1500/₹800 add-ons; `base_price_paise` fallback `2500000` | Add-ons and prices come from the backend; no client-side price invention |
| O7 | `prisma/schema.prisma` `BookingStatus` | Marketplace lifecycle | Enum has `DRIVER_ACCEPTED`; lacks `UNDER_REVIEW`, `VEHICLE_OPTIONS_PREPARED`, `CUSTOMER_CONFIRMATION_PENDING`, `EXPIRED`, `PAYMENT_PENDING`, `PAYMENT_FAILED` | New enum per section 4.1 |
| O8 | `VehicleAssignment.driverId` (`@db.Uuid`, **required**) + `status BookingStatus @default(REQUESTED)` + `acceptedAt/declinedAt/declineReason` | A vehicle cannot be reserved before a chauffeur accepts; drivers accept/decline offers | Schema | `driverId` nullable; separate `AssignmentStatus`; ops assigns the chauffeur |
| O9 | `model Review` | Review is bound to exactly one driver, unmoderated | `driverFk` required, no moderation field | Optional chauffeur link + moderation state; attachable to a group booking |
| O10 | `model Message` | Customer↔driver chat | `senderId`/`recipientId` user-to-user on a booking | Customer↔Operations thread |
| O11 | `model Vehicle.basePricePaise` | One number is the whole tariff | `basePricePaise BigInt @default(0)` | Structured, versioned partner tariff (section 4.4) |
| O12 | whole repo | No favourites persistence | no `FavoriteVehicle` model, no favourites endpoint; Flutter has a local-only shortlist provider | `FavoriteVehicle` on customer account |
| O13 | `backend/src/app.module.ts` | Admin surface exists | `// NEXT: AdminModule, AuditModule`; no `backend/src/admin` | Admin module: verification, price approval, allocation, workspace |
| O14 | `frontend/lib/features/{trips,messages,urgent_dispatch,support}/data/mock_*.dart` | Long-lived mock repositories in the production feature tree | `Mock*Repository` classes | Keep only behind `useMockData`; production default is `false` |
| O15 | `EnvironmentConfig.development` | A dev build without `--dart-define=SHADI_API_BASE_URL` yields an **empty** base URL | `apiBaseUrl: apiBaseUrlOverride ?? const String.fromEnvironment('SHADI_API_BASE_URL')` (default `''`) | Fail fast with a clear message, or supply a documented default |

| O16 | `backend/src/bookings/group-bookings.controller.ts` | A customer's booking is readable by any authenticated caller | `@Get(':id')` had no ownership check — any logged-in user could read another host's addresses, requirements and pricing by guessing/observing an id | Ownership-or-admin enforced in the service; non-owners get the same 404 as a nonexistent id |
| O17 | `backend/src/bookings/group-bookings.controller.ts` (submit DTO) | Each `fleet` line was validated as a whole availability DTO | `@ValidateNested({each: true}) @Type(() => CheckFleetAvailabilityDto)` where that DTO itself contains `fleet` ⇒ **every** real submission 400'd (`vehicleTypeId should not exist`) | A dedicated `FleetRequestLineDto`; regression-tested over HTTP |
| O18 | `GroupBookingsService.assignChauffeur` | Staffing a car rewound the parent booking | Unconditionally set `VEHICLE_OPTIONS_PREPARED` when all cars were staffed — silently un-asking a customer whose confirmation was pending | Advance only from `REQUESTED`/`UNDER_REVIEW`; never move backwards |
| O19 | `GroupBookingsService` raw assignment lock | `$queryRaw` compared `uuid = text` | Postgres error 42883 → **500** on `assign-chauffeur`; verified live | Explicit `::uuid` cast |
| O20 | `frontend/lib/features/bookings/data/booking_api_repository.dart` | Group-booking mapper written against mocks | Read `referenceCode`/`estimatedTotalPaise`/`primaryContactName` (camelCase, never sent), `chauffeur.full_name` and `registration_number` (must never be sent to a customer), and coerced an absent price to 0 | Mapper rewritten to the real snake_case customer contract, nullable prices (`On request`), neutral `chauffeur_assigned` boolean |
| O21 | `frontend/test/features/drivers/driver_customer_booking_flow_test.dart` | A test asserted the RETIRED marketplace flow (customer sees “Driver Accepted” and “Confirmed (ID: d1)”) | Whole-file assertions on offer→accept→identity | Replaced with a managed-model test that asserts the customer is shown a *request* and never chauffeur identity |

`StandbyPoolEntry`, `urgent_dispatch` and `support` are retained: they are
operations/dispatch tooling, not the driver-marketplace flow.

---

## 3. Authentication boundary

Login is **required only for transactional actions**. This is a hard requirement.

| Surface | Auth | Notes |
|---------|------|-------|
| Home, category browse, search, search results, vehicle list, vehicle details, availability | **Public** | `GET /vehicles*` already `@Public()` — the Flutter guard is what blocks it |
| Favourites | Required | Persisted per account |
| Booking draft create/edit, quote, booking request submit | Required | Draft is anonymous-compatible until submit; see section 6 |
| My Bookings, booking detail, reviews | Required | Customer-scoped |
| Profile, addresses | Required | |
| Partner (`/partner/*`) | Required + partner/admin role | |
| Admin (`/admin/*`) | Required + admin role | |

Four client-visible roles: `customer`, `partner`, `admin`. Internally `driver`
(chauffeur), `fleetOwner` and the four admin sub-roles are retained for permissions.

---

## 4. Canonical domain model

### 4.1 Booking lifecycle

```
DRAFT
 → REQUESTED
 → UNDER_REVIEW
 → VEHICLE_OPTIONS_PREPARED
 → CUSTOMER_CONFIRMATION_PENDING
 → CONFIRMED
 → IN_PROGRESS
 → COMPLETED
```

Terminal/side states: `CANCELLED`, `EXPIRED`, `PAYMENT_PENDING`, `PAYMENT_FAILED`.

`DRIVER_ACCEPTED`, `EN_ROUTE`, `ARRIVED` are **removed from the customer-visible
lifecycle**. Trip progress (en route / arrived) becomes `AssignmentStatus`, which is
an operational detail surfaced as "chauffeur on the way", not a booking state.

Backend is authoritative for every transition; each one appends a `BookingEvent`.

### 4.2 Entities

Services in the target model, mapped onto what exists today:

| Target entity | Current state | Action |
|---------------|---------------|--------|
| `User` | exists (`UserRole`, `AccountStatus`) | keep; add `partner` to the client-visible role mapping |
| `Customer` / `CustomerProfile` | exists | keep |
| `Partner` | `DriverProfile` doubles as fleet-owner + chauffeur | add `PartnerProfile` (fleet business) **or** keep `FleetOwnerProfile` and treat `DriverProfile` as the chauffeur entity only — see D1 |
| `Chauffeur` | `DriverProfile` | rename semantics in the API layer only (`chauffeur`), keep table |
| `Vehicle` | exists | add `VehiclePricing` relation; drop reliance on `basePricePaise` |
| `VehicleType` | exists | keep (this is the customer-facing "model" catalog) |
| `VehicleDocument` / `PartnerDocument` | `VehicleDocument` + `DriverDocument` exist | keep |
| `VehiclePricing` / `PricingVersion` | **missing** | add (4.4) |
| `Customer`, `FavoriteVehicle` | favourite model missing | add |
| `BookingRequest` | `Booking` with `status=REQUESTED` | keep, redefine states |
| `GroupBooking` | exists | keep — already "one parent, many assignments" |
| `VehicleAssignment` | exists, driver mandatory | make `driverId` nullable, add `AssignmentStatus` |
| `Quote` | `quotes` module + `PricingRule` | keep; add immutable snapshot onto the booking |
| `Payment` | exists with gateway abstraction | keep |
| `Review` | exists | add moderation + optional chauffeur |
| `Notification` | exists | keep |
| `AuditLog` | exists | keep; wire audit into verification/price/allocation |
| `BookingStatusHistory` | `BookingEvent` | reuse |
| `OtpCode` | exists, hashed, attempt-counted, expiring | keep |

### 4.3 Decisions needed (flagged, not assumed)

- **D1 — Partner vs. chauffeur identity.** Today one `DriverProfile` row is both
  "the fleet owner" and "the chauffeur", and a `Vehicle` points at either an
  `independentDriverId` or a `fleetOwnerId`. The target model separates *partner*
  (business that owns vehicles) from *chauffeur* (person who drives). Recommendation:
  add `PartnerProfile` and keep `DriverProfile` as chauffeur, migrating
  `independentDriverId`-owned vehicles to a partner of the same user.
- **D2 — Multi-vehicle guest selection vs. `POST /bookings`.** The current submit
  endpoint takes exactly one `vehicleTypeId` + quantity via `GroupBooking`. The
  new UI needs a fleet of typed quantities. `GroupBooking.requestedFleet` already
  stores `{"Toyota Innova Crysta": 7}` — promote that to a first-class
  `requestedFleetItems[{vehicleTypeId, quantity}]`.
- **D3 — Address entry.** Location is currently free text (`pickupAddress`) with
  optional lat/lng. PostGIS exists but geographic search is not wired. Decide
  whether pick-up becomes a place-search-backed structured location.

### 4.4 Pricing model (target)

```
VehiclePricing (per vehicle, versioned)
  pricingVersionId
  local:      { includedKm, amountPaise }            e.g. up to 45 km → ₹3,000
  perKmPaise
  hourlyPaise, extraHourPaise
  fullDayPaise
  overnightPaise
  outstation: { perDayPaise, perKmPaise }
  status:     PENDING_REVIEW | APPROVED | REJECTED | SUPERSEDED | ACTIVE
  submittedBy, submittedAt, approvedBy, approvedAt, effectiveFrom, effectiveTo
```

Rules:
1. Partner submits; nothing becomes customer-visible until `APPROVED`.
2. `PricingRule` (vehicle-class × city commercial policy) remains the
   ShadiDriver-level rule; the effective price is the backend's combination.
3. Every booking/quote stores an **immutable snapshot** (rate card + computed
   lines). Editing a tariff never mutates a confirmed booking.
4. Flutter never computes a customer-visible price.

---

## 5. API contract by audience

All routes under `/api/v1`. Response shape is the existing envelope:
`{success, data, meta?}` on success, `{success:false, error:{code,message,details?}, meta}` on failure.

### 5.1 Public (no JWT)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/vehicles` | Search verified, active, available vehicles |
| GET | `/vehicles/types` | Vehicle type catalog |
| GET | `/vehicles/availability` | Available count per type, optional `?city=` |
| GET | `/vehicles/:id` | Vehicle detail |
| GET | `/categories` | Service categories |
| POST | `/availability/search` | Availability for a fleet + window |

**Public vehicle payload — allowed keys (exhaustive):**

```
GET /vehicles        → { items: [PublicVehicleListItem], meta }
PublicVehicleListItem = id, vehicle_type_id, make, model, display_name, year,
  vehicle_class, seating_capacity, city, image_url, amenities,
  verification_status, is_available, has_verified_chauffeur, rating,
  review_count, price_indicator

GET /vehicles/:id    → PublicVehicleDetail = PublicVehicleListItem fields +
  color, fuel_type, air_conditioning, is_vintage, service_areas, photos,
  documents_summary: { total, verified, expiring_soon },
  suitable_ceremonies, pricing_indicator
```

**Forbidden on any public/customer payload:** `chauffeur_name`, `chauffeur_id`,
`chauffeur.{full_name,avatar_url,bio,duty_status,experience_years,license_*}`,
`owner.*`, `registration_number`, document rows, internal notes. Enforced by
response DTO serialization in the backend, not by the Flutter UI.

### 5.2 Authenticated customer

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/me` | Profile + communication preference |
| PATCH | `/me` | Edit name/email/city/preferences |
| POST | `/auth/phone/change/*` | Phone change (requires re-verification) |
| GET/POST/DELETE | `/favorites`, `/favorites/:vehicleId` | Persistent favourites |
| POST | `/booking-drafts` | Create draft |
| PATCH | `/booking-drafts/:id` | Edit draft (same draft id) |
| POST | `/booking-drafts/:id/quote` | Server-authoritative quote |
| POST | `/bookings` | Submit booking request (idempotent) |
| GET | `/bookings`, `/bookings/:id` | History / detail (customer-safe DTO) |
| POST | `/bookings/:id/confirm` | Customer confirms the operations proposal |
| POST | `/reviews` | Review a completed booking |

### 5.3 Partner

`POST /partner/registration`, `GET/PATCH /partner/profile`,
`GET/POST/PATCH/DELETE /partner/vehicles[/:id]`,
`POST /partner/vehicles/:id/documents`, `POST /partner/vehicles/:id/pricing`,
`GET /partner/verification`, `PUT /partner/availability`.

### 5.4 Admin

`GET /admin/dashboard`, `/admin/customers`, `/admin/partners`, `/admin/vehicles`,
`/admin/verification/{queue,partners,vehicles,documents-expiring}`,
`POST /admin/verification/.../{approve,reject,request-changes,suspend}`,
`/admin/pricing/{pending,history}`, `/admin/bookings/{queue,:id}`,
`POST /admin/bookings/:id/{review,prepare-options,allocate,assign-chauffeur,contact,confirm,cancel}`,
`/admin/payments`, `/admin/reviews`, `/admin/audit-logs`.

Note: `/admin/bookings/:id/confirm` is the *operations* confirmation (the system of
record for the customer having agreed), distinct from the customer's own
`POST /bookings/:id/confirm` acknowledgement. Whichever endpoint mutates state
last writes the `BookingEvent` with the actor's identity.

### 5.5 Privacy matrix

| Field | Public | Customer (own booking) | Partner (own fleet) | Admin |
|-------|--------|------------------------|---------------------|-------|
| vehicle make/model/year/colour/photos | yes | yes | yes | yes |
| verification badge | yes | yes | yes | yes |
| registration number | no | no | yes | yes |
| partner identity | no | after confirmation only | yes | yes |
| chauffeur name/photo/phone | **no** | **no** | assigned-only | yes |
| chauffeur verification status | aggregate flag only | aggregate flag only | yes | yes |
| internal ops notes | no | no | no | yes |
| other customers' bookings | no | no | no | yes |

---

## 6. Slice plan

Delivered in vertical slices; each slice must end with a working, verifiable path.

| Slice | Scope | State |
|-------|-------|-------|
| 0 | This document: audit + canonical model + contract | done |
| 1a | Schema foundation: booking lifecycle, `AssignmentStatus`, nullable chauffeur, `FavoriteVehicle`, `VehiclePricing`/`PricingVersion`, review moderation | this change |
| 1b | Backend DTO layer split: `public/`, `customer/`, `partner/`, `admin/` response DTOs + privacy tests | started (public vehicles) |
| 2 | Guest browsing: public routes, vehicle-first card/detail, no chauffeur surfaces, no invented prices | this change |
| 3 | Favourites + profile (API + UI) | done — `backend/src/favorites/`, `frontend/lib/features/favorites/` |
| 4 | Partner onboarding: multi-vehicle fleet, documents, photos | done — `backend/src/partner/` (registration, fleet CRUD, documents, verification submission; verified live over HTTP) |
| 5 | Partner pricing submission + admin approval | done — `backend/src/partner/pricing.service.ts` (versioned submission, always PENDING_REVIEW) + `backend/src/admin/` verification center (partner/vehicle/pricing queues, approve/reject/request-changes, audit-logged, atomic tariff supersession); verified live over HTTP end-to-end. Admin dashboard UI and partner pricing UI still pending (API-first) |
| 6 | Search/availability on real data (incl. fleet quantities) | pending |
| 7 | Guest selection → auth handoff → booking draft persistence | pending |
| 8 | Server quote + immutable snapshot | done — group bookings are priced from each allocated vehicle's newest APPROVED tariff (overnight → full-day → hourly → local package) with an immutable `pricing_snapshot` (tariff id + version + basis); unpriced ⇒ `null` + `quote_pending`, never ₹0. Ops re-quote via `/operations/booking-requests/:id/requote` retains the superseded snapshot |
| 9 | Group booking + operations allocation + chauffeur assignment | done — `backend/src/operations/` (queue, workspace, allocation, chauffeur picker, unassign) + `group_booking_events` history; verified live over HTTP |
| 10 | Admin booking workspace, notes, audit | done (API) — `/api/v1/operations/*` queue + full internal workspace, internal notes, audit-logged mutations; admin/ops Flutter UI still pending |
| 11 | Customer confirmation workflow | done (API) — `POST /group-bookings/:id/transition` (`CONFIRM_BOOKING`/`REVISE_OPTIONS`/`CANCEL`) bound by the same fleet-readiness guard as operations; customer views updated for the managed states |
| 12 | Trip lifecycle + dynamic OTP | done (API) — confirmation mints a hashed trip OTP texted to the customer; chauffeur milestone ladder `EN_ROUTE → ARRIVED → START_SERVICE (OTP) → COMPLETE` per assignment; parent auto-advances to IN_PROGRESS/COMPLETED; verified live over HTTP with two chauffeurs |
| 13 | Reviews + moderation | done (API) — `backend/src/reviews/`: per-vehicle reviews of COMPLETED bookings (server-derived chauffeur attribution, duplicate-proof), moderation queue with PUBLISH/HIDE/REOPEN (audited), public per-vehicle reviews feeding the catalog aggregates; verified live end-to-end |
| 14 | Payments end-to-end | done (API, managed path) — `/api/v1/payments/group/*`: server-derived 25% advance token confirms the booking, balance settlement gates completion (`409 PAYMENT_REQUIRED` on the last chauffeur COMPLETE while unpaid), mandatory gateway-signature capture, webhook routing for group payments, owner/admin settlement history; contract e2e + verified live over HTTP (two chauffeurs, full advance→trip→balance→COMPLETED arc); single-booking legacy path unchanged; Razorpay-style hosted checkout still pending a real gateway |
| 15 | Full Flutter↔API integration cleanup (remove dead mocks from production paths) | pending |

---

## 7. Configuration / credentials required

| Capability | Requirement | Current state |
|------------|-------------|---------------|
| Database | PostgreSQL 16 + PostGIS via `backend/docker-compose.yml` | Docker Desktop must be running |
| SMS OTP | `SMS_PROVIDER=msg91` + `SMS_AUTH_KEY`, `SMS_OTP_TEMPLATE_ID`, `SMS_SENDER_ID` | not configured → provider abstraction + `console` dev provider only |
| Push/WhatsApp | provider credentials for customer communication preferences | not configured |
| Payments | Razorpay/Cashfree keys | `MockGatewayProvider` only |

A feature that depends on an unconfigured provider is reported as
**implemented, unconfigured** — never as "working" behind a fake success path.
