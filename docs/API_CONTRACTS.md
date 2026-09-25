# ShadiDriver - API Contracts & Interface Specifications

**Document Version:** 1.1.0  
**Status:** REFINED INTERFACE SPECIFICATION  
**Author:** Lead Software Architect  
**Protocol:** HTTPS RESTful JSON (v1) | Secure WebSockets (WSS)  

---

## 1. Global API Standards & Envelope

All HTTP communication adheres to RESTful semantics over TLS 1.3.

### 1.1 Endpoint Classification Standard
Every endpoint in this contract is explicitly tagged across four operational axes:
* **Scope**: `[MVP REQUIRED]`, `[MVP OPTIONAL]`, `[PHASE 2]`, or `[PHASE 3+]`
* **Idempotency**: `[IDEMPOTENT - Header Required]` or `[NON-IDEMPOTENT]`
* **Concurrency**: `[CONCURRENCY-SENSITIVE - Optimistic Lock Required]` or `[STANDARD]`
* **Audit**: `[AUDIT-SENSITIVE - Emits Audit Log]` or `[STANDARD]`

### 1.2 Standard Request Headers
| Header Name | Type | Requirement | Description |
| :--- | :--- | :--- | :--- |
| `Authorization` | String | Required (Protected endpoints) | `Bearer <JWT_ACCESS_TOKEN>` |
| `Idempotency-Key` | UUID / String | Required on all `[IDEMPOTENT]` endpoints | Client-generated key preventing duplicate mutations |
| `X-Correlation-ID` | UUID | Strongly Recommended | Distributed trace ID logged across all systems |
| `X-App-Version` | String | Required | Semantic version of client (e.g., `1.0.0+42`) |
| `X-Platform` | String | Required | `IOS`, `ANDROID`, or `WEB` |
| `X-Device-ID` | String | Required | Hardware identifier for session binding |

### 1.3 Unified Response Envelopes

#### Success Response
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "page": 1,
    "limit": 20,
    "total_records": 105,
    "has_more": true
  }
}
```

#### Error Response
```json
{
  "success": false,
  "error": {
    "code": "BOOKING_SLOT_UNAVAILABLE",
    "message": "The selected luxury vehicle is already reserved for this date and time slot.",
    "details": {
      "conflicting_booking_id": "018e3a2b-8a5f-7622-921c-a612501a3002",
      "available_from": "2026-11-20T18:00:00Z"
    }
  }
}
```

---

## 2. Authentication & Identity Endpoints

> **Request bodies are camelCase, response data keys are snake_case.** Request
> DTOs use camelCase field names (`phoneNumber`, `displayName`, `role`,
> `sessionId`, `otpCode`, `refreshToken`, `deviceId`) and the global
> `ValidationPipe` runs with `whitelist + forbidNonWhitelisted`, so any
> snake_case request key (e.g. `phone_number`) is rejected with
> `property phone_number should not exist`. Response `data` keys keep the
> documented snake_case names (`session_id`, `access_token`, …).

### 2.1 Request Phone OTP
* **Scope:** `[MVP REQUIRED]` | `[NON-IDEMPOTENT]` | `[STANDARD]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/auth/otp/request`
* **Auth:** Public
* **Request Payload:**
```json
{
  "phoneNumber": "+919876543210",
  "purpose": "LOGIN"
}
```
* **Backend Validation:** Validates E.164 phone format (`/^\+[1-9]\d{7,14}$/`) and the `purpose` enum; checks IP rate limit (max 3 per 5 min).
* **Response `200 OK`:**
```json
{
  "success": true,
  "data": {
    "session_id": "otp_sess_018e3a2b8a5f",
    "expires_in_seconds": 120,
    "resend_available_in_seconds": 30
  }
}
```
> The issued OTP is never returned to the client. `debug_code` is included only
> when the server is explicitly started with `OTP_DEBUG_EMIT=true` in a
> non-production environment.

### 2.1a Register (Create Account)
* **Scope:** `[MVP REQUIRED]` | `[NON-IDEMPOTENT]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/auth/signup`
* **Auth:** Public (customer/driver only; admin accounts are provisioned internally)
* **Request Payload:**
```json
{
  "phoneNumber": "+919876543210",
  "displayName": "Aarav Sharma",
  "role": "customer"
}
```
* **Backend Validation:** `phoneNumber` — E.164 string, and for `signup` an Indian
  mobile `/^\+91[6-9]\d{9}$/`; `displayName` — string, 2–150 chars;
  `role` — one of `customer` | `driver`. Unknown properties are rejected.
* **Response `200 OK`:**
```json
{
  "success": true,
  "data": {
    "session_id": "otp_sess_018e3a2b8a5f",
    "expires_in_seconds": 300,
    "next_step": "VERIFY_OTP"
  }
}
```
* An existing phone number returns `409 PHONE_ALREADY_REGISTERED`.

### 2.2 Verify OTP & Authenticate
* **Scope:** `[MVP REQUIRED]` | `[NON-IDEMPOTENT]` | `[STANDARD]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/auth/otp/verify`
* **Auth:** Public
* **Request Payload:**
```json
{
  "sessionId": "otp_sess_018e3a2b8a5f",
  "otpCode": "849201",
  "deviceId": "dev_f47ac10b-58cc-4372-a567-0e02b2c3d479"
}
```
* **Response `200 OK`:** Returns signed JWT access token (15-min TTL) and rotating refresh token.

---

## 3. Catalog & Price Quotation Endpoints

### 3.0 Public Vehicle Catalog (browsable WITHOUT authentication)

Authentication is required only for transactional actions. These endpoints are
`@Public()` and are the basis of the vehicle-first experience: a customer
selects cars first and signs in only when they book.

* `GET /api/v1/vehicles` — verified + active + available vehicles.
  Query: `city`, `vehicleTypeId` (csv), `vehicleClass`, `minSeatingCapacity`, `page`, `limit`.
* `GET /api/v1/vehicles/types` — active vehicle-type catalog.
* `GET /api/v1/vehicles/availability?city=` — available count per vehicle type.
* `GET /api/v1/vehicles/:id` — vehicle detail.

**Source of truth:** `backend/src/vehicles/dto/public-vehicle.dto.ts`
(`PUBLIC_VEHICLE_LIST_KEYS`, `PUBLIC_VEHICLE_DETAIL_KEYS`).

`GET /vehicles` item — exhaustive key list:
```json
{
  "id": "bb15afd5-38ca-4ae1-a6f9-e42250ed5952",
  "vehicle_type_id": "VT_INNOVA_CRYSTA",
  "fleet_code": "SD-VH-0001",
  "make": "Toyota",
  "model": "Innova Crysta",
  "display_name": "Toyota Innova Crysta",
  "year": 2023,
  "vehicle_class": "EXECUTIVE_MPV",
  "seating_capacity": 7,
  "city": "Delhi NCR",
  "image_url": null,
  "amenities": ["AC"],
  "verification_status": "APPROVED",
  "is_available": true,
  "has_verified_chauffeur": true,
  "rating": 4.5,
  "review_count": 12,
  "price_indicator_paise": "2500000"
}
```

`price_indicator_paise` is **nullable**. It is derived exclusively from the
vehicle's newest `APPROVED` tariff (`vehicle_pricing`, via
`cheapestIndicativePaise` over the entry amounts: local package, full day,
overnight, outstation day). It is `null` when no tariff has been approved —
per-km and per-hour rates are incremental and never count as a price.

> Regression guard: the indicator once read the legacy `base_price_paise`
> column (default `0`), which advertised every freshly-onboarded partner
> vehicle as "From ₹0". It must never be published from that column again.
> Clients render `null` as "Price on request" and must not treat unpriced
> vehicles as the cheapest in sort, or as matching a budget filter
> (enforced in `SortEngine._sortByPrice` / `FilterEngine`, tested in
> `frontend/test/features/vehicles/unpriced_vehicle_test.dart` and
> `backend/src/vehicles/vehicles.public-dto.spec.ts`).

`GET /vehicles/:id` adds: `color`, `fuel_type`, `air_conditioning`, `is_vintage`,
`service_areas`, `photos`, `documents_summary {total, verified, expiring_soon}`,
`suitable_ceremonies`.

**Privacy invariant (enforced by response DTO, not by the client):** a public or
customer vehicle payload must NEVER contain `chauffeur`, `chauffeur_name`,
`chauffeur_id`, `driver`, `owner`, `registration_number`, document rows or
internal notes. Trust is conveyed by the boolean `has_verified_chauffeur`.
Verified by `backend/src/vehicles/vehicles.public-dto.spec.ts`.

### 3.1 Fetch Ceremony Categories
* **Scope:** `[MVP REQUIRED]` | `[NON-IDEMPOTENT]` | `[STANDARD]` | `[STANDARD]`
* **Status:** ⚠️ **DOCUMENTED BUT NOT IMPLEMENTED** — there is no `catalog`
  module in `backend/src`. The implemented equivalent is
  `GET /api/v1/quotes/categories` (see `backend/src/quotes/quotes.controller.ts`).
* **Endpoint:** `GET /api/v1/catalog/categories`
* **Auth:** Public
* **Response `200 OK`:** Array of active ceremony categories (Baraat, Vidai, Entry, Multi-Day, Reception).

### 3.2 Request Authoritative Price Estimate
* **Scope:** `[MVP REQUIRED]` | `[NON-IDEMPOTENT]` | `[STANDARD]` | `[STANDARD]`
* **Endpoint:** `POST /api/v1/catalog/estimate`
* **Auth:** Public / Authenticated
* **Request Payload:**
```json
{
  "service_category_id": "SVC_BARAAT",
  "vehicle_class": "LUXURY_SEDAN",
  "city_code": "DEL",
  "event_start_time": "2026-11-20T16:00:00+05:30",
  "event_end_time": "2026-11-20T21:00:00+05:30",
  "selected_addon_ids": ["018e3a2b-8a5f-7622-921c-a612501a3009"]
}
```
* **Status:** ⚠️ **DOCUMENTED BUT NOT IMPLEMENTED** — there is no `catalog`
  module in `backend/src`; use the `quotes` module.
* **Backend Validation Invariant:** Backend independently loads `pricing_rules` and computes fare, overage, taxes, and token. **Never trusts client math.**
* **Response `200 OK`:** Itemized quote with `total_cents`, `advance_token_cents`, and `pricing_rule_id`.

---

### 3.4 Favourites (authenticated customer)

Saved vehicles are an **account** feature. A signed-out visitor keeps a
session-local shortlist only; the moment they authenticate the client hands
that shortlist to the server so nothing they saved while browsing is lost.

* `GET /api/v1/favorites` — saved vehicles
* `POST /api/v1/favorites/:vehicleId` — save (idempotent)
* `DELETE /api/v1/favorites/:vehicleId` — unsave (idempotent)
* `POST /api/v1/favorites/merge` — import a guest shortlist (idempotent)

**Auth:** bearer token, role `customer`. A chauffeur/admin account receives
`403 ROLE_FORBIDDEN`. Identity always comes from the token —
`POST /favorites/merge` rejects a client-supplied `customerId` with
`400 VALIDATION_FAILED` (`property customerId should not exist`).

**Request body** (`merge`) — the only field, camelCase, max 100 entries:
```json
{ "vehicleIds": ["661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e"] }
```

**Response `200 OK`:**
```json
{
  "items": [ /* PublicVehicleListItem — see §3.0 */ ],
  "vehicle_ids": ["661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e"],
  "total": 1,
  "unavailable_count": 0,
  "ignored_vehicle_ids": ["stale-id"]
}
```
* `items` use the SAME public projection as the catalog, so favourites can
  never expose chauffeur or partner identity.
* `unavailable_count` counts saved vehicles that left the catalog (suspended,
  expired, withdrawn). They stay saved and are reported, never silently dropped.
* `ignored_vehicle_ids` lists guest-shortlist entries the server could not
  import (unknown, unlisted, malformed). A stale shortlist never fails a sign-in.
* Saving an unlisted vehicle returns `404 NOT_FOUND`, so this endpoint cannot be
  used to probe for unpublished fleet.

**Source of truth:** `backend/src/favorites/`, verified by
`backend/src/favorites/favorites.service.spec.ts` and
`backend/test/favorites-contract.e2e-spec.ts`.

> **Retiring:** the old client-only `shortlistProvider` (session-scoped, never
> persisted) was removed. Favourites have one source of truth.

---

### 5.3 Group Booking — customer request → operations allocation

`POST /api/v1/group-bookings` (auth required, `Idempotency-Key`)

A customer submission is a **REQUEST**, not a commitment: no chauffeur is bound
and nothing is promised to the customer until ShadiDriver operations has
reviewed the request and the customer has confirmed the proposal.

Optional request fields: `requirements: string[]` (max 20, e.g. `"Wedding
decoration"`, `"Child seat"`), `communicationPreference: "PHONE" | "WHATSAPP"
|"EMAIL" | "PHONE_WHATSAPP"`.

Lifecycle (backend-authoritative,
`backend/src/booking-state-machine/booking-status.ts`):
```
DRAFT → REQUESTED → UNDER_REVIEW → VEHICLE_OPTIONS_PREPARED
      → CUSTOMER_CONFIRMATION_PENDING → CONFIRMED → IN_PROGRESS → COMPLETED
```
Side states: `CANCELLED`, `EXPIRED`, `PAYMENT_PENDING`, `PAYMENT_FAILED`.

Operations actions (role `operationsAdmin`):
* `POST /api/v1/group-bookings/assignments/:id/confirm-vehicle` — `PROPOSED → VEHICLE_CONFIRMED`
* `POST /api/v1/group-bookings/assignments/:id/assign-chauffeur` — `{driverId}`; locks the chauffeur's calendar

Chauffeur actions — an acknowledgement of an assigned duty, **never a customer
booking offer**:
* `GET /api/v1/group-bookings/driver/assignments` (own duties only)
* `POST /api/v1/group-bookings/assignments/:id/acknowledge`
* `POST /api/v1/group-bookings/assignments/:id/decline` — the vehicle stays
  reserved; the duty returns to the operations queue and the customer sees no churn

**Customer-facing payload** (`serializeCustomerGroupBooking`) exposes only:
reference, ceremony, city, addresses, service window, passenger count, status,
amounts, requirements, communication preference, requested fleet and, per
assignment, the vehicle's display name + `fleet_code`, `chauffeur_assigned:
boolean` and a neutral `service_state`
(`BEING_PREPARED | ON_THE_WAY | ARRIVED | IN_SERVICE | COMPLETED | CANCELLED`).
It never contains the chauffeur's identity, the partner, the registration plate
or a decline reason.

> ⚠️ **Retiring:** `GET /bookings/driver/offers`, `POST /bookings/:id/accept` and
> `POST /bookings/:id/decline` are the legacy driver-marketplace surface. They are
> no longer part of the product model and are scheduled for removal from the
> Flutter driver app.

---

## 4. Partner (Fleet) Onboarding & KYC Endpoints

> Replaces the old single-vehicle "chauffeur onboarding" surface (§4.1/§4.2
> below, kept until the partner app migrates). A partner is a fleet owner OR a
> single-car chauffeur: one account, many vehicles. **Implemented and
> verified against the running backend** — module `backend/src/partner/`.

### 4.0 Partner Registration & Fleet Management (Implemented)
* **Auth:** required, roles `DRIVER` or `FLEET_OWNER`; a customer token gets `403 ROLE_FORBIDDEN`.
* **Base:** `/api/v1/partner`

| Method & path | Purpose | Notes |
|---|---|---|
| `POST /registration` | Create the partner profile (idempotent) | Promotes a `driver` account to `fleet_owner`; never auto-approves. Body cannot carry `verificationStatus`, PAN/GSTIN are format-validated. |
| `GET /profile` | Profile + verification state | Adds `vehicle_count`, `document_count`. |
| `PATCH /profile` | Edit professional/legal details | Editing an `APPROVED` partner returns it to `UNDER_REVIEW`; a `SUSPENDED` partner cannot edit. |
| `POST /submit` | Submit partner + fleet for verification | Refused with `VALIDATION_FAILED` while the fleet is empty. |
| `GET /vehicles` | The caller's own fleet | Only ever the token's partner fleet. |
| `POST /vehicles` | Add one vehicle | Server generates `fleet_code` (`SD-<CITY>-00001`). New vehicle is `PENDING_SUBMISSION`, `is_bookable=false`. Plate regex, fuel/transmission enums, year bounds enforced. |
| `PATCH /vehicles/:vehicleId` | Edit vehicle facts | Plate and vehicle type are NOT editable. An `APPROVED` vehicle returns to `PENDING_SUBMISSION` (out of the public catalog) until re-approved. |
| `DELETE /vehicles/:vehicleId` | Soft-remove | Refused with `CONFLICT` while committed to an upcoming booking; otherwise `is_active=false`, row kept for history. |
| `POST /vehicles/:vehicleId/documents` | Upload/replace vehicle paperwork | `PENDING_REVIEW`; re-upload clears prior verification. |
| `POST /documents` | Partner-level document | Same re-review semantics. |

**Invariants (all covered by `partner.service.spec.ts` + `test/partner-contract.e2e-spec.ts` + live HTTP verification):**

1. **No self-service privileges.** Every request body is `forbidNonWhitelisted` —
   a partner cannot inject `verificationStatus`, `isActive`, `isAvailable`,
   `isBookable`, `fleetOwnerId`, `fleetCode`, prices or `chauffeurId`; those
   attempts are `400` with `property X should not exist`.
2. **A partner can never make its own vehicle bookable.** Only admin
   verification (`APPROVED` on the *vehicle*) publishes a car; a verified
   partner with unverified cars has `is_verified=true` and every
   `is_bookable=false`.
3. **IDOR-safe ownership.** Another partner's vehicle id returns
   `404 NOT_FOUND` (never `403`), so the API cannot be probed to enumerate
   anyone's fleet. A second partner's `GET /vehicles` is empty.
4. **Malformed ids are client errors.** `ParseUUIDPipe` rejects
   `/vehicles/not-a-uuid` with `400`, never a `500`.
5. **No pricing here.** Tariffs are a separate reviewed resource (§3.0's
   approved-tariff price indicator); `AddVehicleDto` carries no price field.

### 4.0.1 Partner Tariff Submission (Implemented)
* **Auth:** required, roles `DRIVER` / `FLEET_OWNER` (same gate as §4.0).
* **Endpoints:**
  * `POST /api/v1/partner/vehicles/:vehicleId/pricing` — submit a new tariff
    version. **Always starts `PENDING_REVIEW`**; a body cannot carry
    `status`/approval fields (`400 property status should not exist`). The
    latest approved tariff stays live until an admin approves the successor.
  * `GET /api/v1/partner/vehicles/:vehicleId/pricing` — full version history,
    newest first, with `live_version` flagged.
* **Wire format (all paise, as strings):** `local_included_km`,
  `local_amount_paise`, `per_km_paise`, `hourly_paise`, `extra_hour_paise`,
  `full_day_paise`, `overnight_paise`, `outstation_per_day_paise`,
  `outstation_per_km_paise`, `status`, `submitted_at`, `reviewed_at`,
  `decision_reason`, `effective_from`, `is_live`.
* **Sanity rules (rejected with `VALIDATION_FAILED` before insert):**
  `full_day_paise ≥ local_amount_paise` and `≥ 4 × hourly_paise`;
  `overnight_paise ≥ full_day_paise`;
  `outstation_per_km_paise ≥ per_km_paise`. There is deliberately NO floor on
  `outstation_per_day_paise` — the standard Indian commercial model prices the
  outstation day below a city full-day package because per-km charges
  accumulate over long distances on top of it.
* **Ownership:** another partner's vehicle is `404 NOT_FOUND` (never `403`).

### 4.0.2 Admin Verification Center (Implemented)
* **Auth:** required, roles `operationsAdmin` / `verificationAdmin` /
  `financeAdmin` / `superAdmin`. Customer/driver/fleetOwner tokens get
  `403 ROLE_FORBIDDEN` from every admin route.
* **Queues:**
  * `GET /api/v1/admin/verification/partners` — `SUBMITTED` partners,
    oldest first, with `fleet_size` / `fleet_pending` and contact phone
    (admin-only data).
  * `GET /api/v1/admin/verification/vehicles` — `PENDING_SUBMISSION` /
    `UNDER_REVIEW` / `ACTION_REQUIRED` vehicles with partner identity and
    document rows (admin-only data).
  * `GET /api/v1/admin/pricing/queue` — `PENDING_REVIEW` tariffs shown
    side-by-side with the currently-live approved tariff.
* **Decisions** (`POST`, body `{ "action": ..., "decisionReason?": ... }`):
  * `POST /admin/verification/partners/:partnerId` — APPROVE / REJECT /
    REQUEST_CHANGES / SUSPEND. APPROVE verifies the PARTNER only — vehicles
    are verified separately. REJECT / REQUEST_CHANGES REQUIRE a reason
    (`400 decisionReason is required` otherwise).
  * `POST /admin/verification/vehicles/:vehicleId` — same verbs; APPROVE
    publishes the vehicle into the public catalog (the catalog's eligibility
    rule is `APPROVED`), REQUEST_CHANGES maps to `ACTION_REQUIRED`.
  * `POST /admin/pricing/:pricingId/decision` — APPROVE atomically supersedes
    the previous live version and activates the submitted one in one
    transaction; only `PENDING_REVIEW` rows can be approved (re-approving
    history is a `409 CONFLICT`); REJECT keeps the live tariff untouched;
    REQUEST_CHANGES keeps the tariff pending with the reason recorded.
* **Audit:** every decision writes an `audit_logs` row
  (`PARTNER_VERIFICATION_DECIDED`, `VEHICLE_VERIFICATION_DECIDED`,
  `PRICING_APPROVED` / `PRICING_DECIDED`, plus `PRICING_SUBMITTED` on the
  partner side) with actor id/role, target entity/id and the from→to change.
* **Verified live:** partner submits (v1) → admin approves vehicle + tariff →
  car appears in the public catalog with `price_indicator_paise` from the
  approved tariff and zero private keys; v2 submission does not move the live
  price, is REJECTED with a reason, live price unchanged; v3 REQUEST_CHANGES
  stays pending with the reason visible to the partner; 8 audit rows written.


### 4.1 Register Chauffeur Profile (legacy — pre-replatform)
* **Scope:** `[MVP REQUIRED]` | `[NON-IDEMPOTENT]` | `[STANDARD]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/drivers/register`
* **Auth:** Required (`DRIVER` role)
* **Request Payload:**
```json
{
  "experience_years": 8,
  "languages_spoken": ["Hindi", "English", "Punjabi"],
  "ceremonial_attire_sizes": { "suit": "42R", "safa": "L", "height_cm": 180 }
}
```

### 4.2 Submit Verification Document (legacy — pre-replatform)
* **Scope:** `[MVP REQUIRED]` | `[IDEMPOTENT - Header Required]` | `[STANDARD]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/drivers/documents`
* **Auth:** Required (`DRIVER` role)
* **Payload:** `multipart/form-data` with document file, type, and dates.
* **Storage Invariant:** File streamed directly to private S3 bucket with server-side encryption. Public access blocked.

---

## 5. Booking Lifecycle Endpoints

### 5.1 Create Wedding Booking Request
* **Scope:** `[MVP REQUIRED]` | `[IDEMPOTENT - Header Required]` | `[CONCURRENCY-SENSITIVE]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/bookings`
* **Auth:** Required (`CUSTOMER` role)
* **Headers:** `Idempotency-Key: <string, min 8 chars>` (required; never sent in the body)
* **Source of truth:** `backend/src/bookings/bookings.controller.ts` → `class SubmitBookingDto`.
  The global `ValidationPipe` runs with `whitelist: true, forbidNonWhitelisted: true`, so this
  field list is exact — any extra key is rejected with `property <key> should not exist`,
  and any missing required key with `<key> must be a string`.
* **Request Payload** (camelCase, flat; the same names the mobile client sends):
```json
{
  "serviceCategoryId": "SVC_BARAAT",
  "vehicleTypeId": "661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e",
  "ceremonyType": "Baraat",
  "ceremonialAttire": "Safa & Bandhgala",
  "specialInstructions": "Slow procession speed required.",
  "serviceStartTime": "2026-11-20T16:00:00+05:30",
  "serviceEndTime": "2026-11-20T21:00:00+05:30",
  "city": "Delhi NCR",
  "pickupAddress": "Oberoi Grand Ballroom, MG Road, New Delhi",
  "destinationAddress": "Grand Imperial Banquets, MG Road, Gurugram",
  "venueName": "Grand Imperial Banquets",
  "routeDistanceKm": 42,
  "primaryContactName": "Aarav Sharma",
  "primaryContactPhone": "+919810000001",
  "passengerCount": 4,
  "selectedAddonIds": ["018e3a2b-8a5f-7622-921c-a612501a3009"]
}
```
* **Field rules** (mirrored client-side in `frontend/lib/features/bookings/data/dto/submit_booking_dto.dart`;
  the client refuses locally instead of spending a request the server would reject):

| Field | Required | Rule |
| --- | --- | --- |
| `serviceCategoryId` | yes | string, 2–50 |
| `vehicleTypeId` | yes | string, 2–50 — accepts a vehicle UUID **or** a vehicle-type id |
| `ceremonyType` | yes | string, 2–60 |
| `ceremonialAttire` | yes | string, 2–100 |
| `specialInstructions` | no | string |
| `serviceStartTime` / `serviceEndTime` | yes | ISO date string; end after start, min 1 hour, start in the future |
| `city` | yes | string, 2–50 |
| `pickupAddress` / `destinationAddress` | yes | string, **5–500 characters** |
| `venueName` | no | string |
| `routeDistanceKm` | no | number ≥ 0 |
| `primaryContactName` | yes | string, 2–120 |
| `primaryContactPhone` | yes | string, 8–20 |
| `passengerCount` | yes | integer, 1–60 |
| `selectedAddonIds` | no | string[] |

* **Backend Validation:** start time in the future, end after start, minimum 1 hour, verifies the
  vehicle type is active, executes the authoritative price calculation (client amounts are never
  read), places a calendar lock at accept time.
* **Response `201 Created`:** Returns `{ booking, idempotent_replay }` with the booking in
  `REQUESTED` state and the server-computed `estimatedTotalPaise` / `advanceTokenPaise`
  (paise amounts are serialized as strings).

### 5.2 Transition Booking Lifecycle State
* **Scope:** `[MVP REQUIRED]` | `[IDEMPOTENT - Header Required]` | `[CONCURRENCY-SENSITIVE]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/bookings/{booking_id}/transition`
* **Auth:** Required (`DRIVER`, `CUSTOMER`, or `OPERATIONS_ADMIN`)
* **Headers:** `Idempotency-Key: <UUID>`
* **Request Payload:**
```json
{
  "action": "START_TRIP",
  "current_version": 4,
  "location": { "latitude": 28.5912, "longitude": 77.2341, "accuracy_meters": 5.2 },
  "notes": "Baraat procession officially started."
}
```
* **Concurrency Enforcement:** Must match `current_version` in DB; increments version atomically. Appends immutable entry to `booking_events`.
* **Response `200 OK`:** Returns new booking status and updated version.

---

## 6. Payments & Settlement Endpoints

### 6.1 Create Payment Order (Advance Token / Settlement)
* **Scope:** `[MVP REQUIRED]` | `[IDEMPOTENT - Header Required]` | `[CONCURRENCY-SENSITIVE]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/payments/create-order`
* **Auth:** Required (`CUSTOMER` role)
* **Headers:** `Idempotency-Key: <UUID>`
* **Payment Gateway Standard:** `[RECOMMENDED BUT NOT YET FINAL - Razorpay / Cashfree]`
* **Request Payload:**
```json
{
  "booking_id": "018e3a2b-8a5f-7622-921c-a612501a3099",
  "payment_type": "ADVANCE_TOKEN"
}
```
* **Backend Invariant:** Calculates exact required token from `bookings` table. Never accepts amount from client.
* **Response `200 OK`:** Returns gateway order ID, currency, and cryptographic session key for checkout.

### 6.2 Payment Webhook Ingestion
* **Scope:** `[MVP REQUIRED]` | `[IDEMPOTENT - Header Required]` | `[CONCURRENCY-SENSITIVE]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/payments/webhook`
* **Auth:** Cryptographic Webhook Signature Header (`X-Gateway-Signature: HMAC-SHA256`)
* **Backend Invariant:** Rejects any webhook failing signature verification. Processes transaction idempotently using `gateway_payment_id`. Transitions booking to `CONFIRMED`.

---

## 7. Real-Time Telemetry Contracts (WebSocket)

### 7.1 Chauffeur Telemetry Uplink
* **Scope:** `[MVP REQUIRED]` | `[NON-IDEMPOTENT]` | `[STANDARD]` | `[STANDARD]`
* **Path:** `WSS /ws/v1/tracking/driver`
* **Payload:** `{ driver_id, booking_id, coordinates: { lat, lng, speed, bearing }, timestamp }`
* **Backend Invariant:** Validates timestamp drift `< 5 min`; updates Redis geo-index; broadcasts to active customer room.

### 7.2 Customer Live Map Stream
* **Scope:** `[MVP REQUIRED]` | `[NON-IDEMPOTENT]` | `[STANDARD]` | `[STANDARD]`
* **Path:** `WSS /ws/v1/tracking/booking/{booking_id}`
* **Payload:** Stream of interpolated chauffeur coordinates, bearing, and estimated arrival minutes.

---

## 8. Admin Operations & Control Room Endpoints

### 8.1 Review Verification Document
* **Scope:** `[MVP REQUIRED]` | `[IDEMPOTENT - Header Required]` | `[STANDARD]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/admin/verifications/{document_id}/decision`
* **Auth:** Required (`VERIFICATION_ADMIN` or `SUPER_ADMIN`)
* **Payload:** `{ decision: "APPROVED" | "REJECTED" | "ACTION_REQUIRED", reason: "..." }`
* **Audit:** Mandatory log entry in `verification_records` and `audit_logs`.

### 8.2 Emergency Standby Chauffeur Reassignment
* **Scope:** `[MVP REQUIRED]` | `[IDEMPOTENT - Header Required]` | `[CONCURRENCY-SENSITIVE]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/admin/bookings/{booking_id}/emergency-reassign`
* **Auth:** Required (`OPERATIONS_ADMIN` or `SUPER_ADMIN`)
* **Payload:** `{ reason: "VEHICLE_BREAKDOWN", replacement_driver_id: "...", replacement_vehicle_id: "..." }`
* **Concurrency:** Transactionally releases original driver calendar lock and assigns replacement.

---

## 9. Domain Error Taxonomy

| Error Code | HTTP Status | Meaning | Resolution Path |
| :--- | :--- | :--- | :--- |
| `AUTH_INVALID_TOKEN` | 401 | Access token expired, invalid signature, or revoked | Refresh token or re-authenticate |
| `ROLE_FORBIDDEN` | 403 | Actor lacks role permission for the requested resource | Access denied |
| `DOC_NOT_VERIFIED` | 403 | Chauffeur has unverified or expired mandatory credentials | Complete KYC pipeline |
| `BOOKING_NOT_FOUND` | 404 | Booking ID does not exist | Check reference identifier |
| `INVALID_TRANSITION` | 409 | Attempted illegal state machine transition | Fetch latest booking version |
| `VERSION_CONFLICT` | 409 | Concurrent modification conflict (Optimistic lock) | Refresh state and retry |
| `SLOT_DOUBLE_BOOKED` | 409 | Chauffeur or vehicle already committed to another booking | Select alternate chauffeur/tier |
| `IDEMPOTENT_REPLAY` | 200/409 | Request with this idempotency key was previously processed | Return cached transaction result |
| `PAYMENT_DECLINED` | 402 | Gateway declined transaction (insufficient funds, 3DS fail)| Prompt alternate payment method |
