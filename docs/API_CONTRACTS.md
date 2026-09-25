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

### 3.1 Fetch Ceremony Categories
* **Scope:** `[MVP REQUIRED]` | `[NON-IDEMPOTENT]` | `[STANDARD]` | `[STANDARD]`
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
* **Backend Validation Invariant:** Backend independently loads `pricing_rules` and computes fare, overage, taxes, and token. **Never trusts client math.**
* **Response `200 OK`:** Itemized quote with `total_cents`, `advance_token_cents`, and `pricing_rule_id`.

---

## 4. Chauffeur Onboarding & KYC Endpoints

### 4.1 Register Chauffeur Profile
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

### 4.2 Submit Verification Document
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
