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

### 2.1 Request Phone OTP
* **Scope:** `[MVP REQUIRED]` | `[NON-IDEMPOTENT]` | `[STANDARD]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/auth/otp/request`
* **Auth:** Public
* **Request Payload:**
```json
{
  "phone_number": "+919876543210",
  "app_role": "CUSTOMER"
}
```
* **Backend Validation:** Validates E.164 phone format, checks IP rate limit (max 3 per 5 min), verifies role string.
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

### 2.2 Verify OTP & Authenticate
* **Scope:** `[MVP REQUIRED]` | `[NON-IDEMPOTENT]` | `[STANDARD]` | `[AUDIT-SENSITIVE]`
* **Endpoint:** `POST /api/v1/auth/otp/verify`
* **Auth:** Public
* **Request Payload:**
```json
{
  "session_id": "otp_sess_018e3a2b8a5f",
  "otp_code": "849201",
  "device_id": "dev_f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "fcm_token": "fcm_token_string..."
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
* **Headers:** `Idempotency-Key: <UUID>`
* **Request Payload:**
```json
{
  "service_category_id": "SVC_BARAAT",
  "vehicle_class": "LUXURY_SEDAN",
  "event_start_time": "2026-11-20T16:00:00+05:30",
  "event_end_time": "2026-11-20T21:00:00+05:30",
  "pickup_address": "Oberoi Grand Ballroom, MG Road, New Delhi",
  "pickup_coordinates": { "latitude": 28.5912, "longitude": 77.2341 },
  "ceremony_venue_name": "Grand Imperial Banquets",
  "selected_attire": "ROYAL_BANDHGALA_SAFA",
  "selected_addons": ["018e3a2b-8a5f-7622-921c-a612501a3009"],
  "special_instructions": "Slow procession speed required."
}
```
* **Backend Validation:** Validates start time is in future, verifies vehicle class availability, executes authoritative price calculation, places temporary calendar lock.
* **Response `201 Created`:** Returns booking record in `REQUESTED` state with computed `advance_token_cents`.

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
