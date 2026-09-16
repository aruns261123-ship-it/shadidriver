# ShadiDriver — Backend Readiness Guide

## 1. Executive Summary
This document defines the complete backend readiness profile for the ShadiDriver Flutter/Dart mobile client.
The client application is built with **Feature-first Clean Architecture**, where 100% of data access is abstracted behind pure Dart domain repository interfaces. The mobile application is completely decoupled from database drivers, third-party backend SDKs, and payment gateways.

---

## 2. Client-Side Repository Abstractions & Backend Endpoints

| Domain Repository | Current Mock Implementation | Target REST / HTTP Endpoint | Primary DTOs |
|---|---|---|---|
| `AuthRepository` | `MockAuthRepository` | `POST /api/v1/auth/otp/request`<br>`POST /api/v1/auth/otp/verify`<br>`POST /api/v1/auth/session/refresh`<br>`POST /api/v1/auth/signout` | `OtpRequestDto`<br>`OtpVerifyDto`<br>`AuthSessionDto` |
| `BookingRepository` | `MockBookingRepository` | `POST /api/v1/bookings/drafts`<br>`POST /api/v1/bookings/submit`<br>`GET /api/v1/bookings/my`<br>`GET /api/v1/bookings/:id`<br>`POST /api/v1/bookings/:id/accept`<br>`POST /api/v1/bookings/:id/decline` | `BookingDraftDto`<br>`BookingSubmissionRequestDto`<br>`BookingSubmissionResultDto`<br>`BookingSummaryDto` |
| `DriverRepository` | `MockDriverRepository` | `GET /api/v1/driver/duty-status`<br>`PUT /api/v1/driver/duty-status`<br>`GET /api/v1/driver/offers`<br>`POST /api/v1/driver/offers/:id/accept`<br>`POST /api/v1/driver/offers/:id/decline` | `DriverDutyStatusDto`<br>`DriverBookingOfferDto`<br>`DriverDeclineReasonDto` |
| `TripRepository` | `MockTripRepository` | `POST /api/v1/trips/:id/milestones/arrived`<br>`POST /api/v1/trips/:id/start`<br>`POST /api/v1/trips/:id/complete` | `TripMilestoneDto`<br>`StartOtpVerificationDto` |
| `VehicleRepository` | `MockVehicleRepository` | `GET /api/v1/vehicles/featured`<br>`GET /api/v1/vehicles/search`<br>`GET /api/v1/vehicles/:id` | `VehicleSummaryDto`<br>`VehicleDetailsDto` |
| `CustomerProfileRepository` | `MockCustomerProfileRepository` | `GET /api/v1/users/profile`<br>`PUT /api/v1/users/profile` | `CustomerProfileDto` |
| `DriverProfileRepository` | `MockDriverProfileRepository` | `GET /api/v1/drivers/profile`<br>`PUT /api/v1/drivers/profile` | `DriverProfileDto` |
| `AdminProfileRepository` | `MockAdminProfileRepository` | `GET /api/v1/admin/profile`<br>`PUT /api/v1/admin/profile` | `AdminProfileDto` |
| `SavedAddressesRepository` | `MockSavedAddressesRepository` | `GET /api/v1/users/addresses`<br>`POST /api/v1/users/addresses`<br>`DELETE /api/v1/users/addresses/:id` | `SavedAddressDto` |
| `PaymentRepository` | `MockPaymentRepository` | `POST /api/v1/payments/advance-token/order`<br>`POST /api/v1/payments/verify` | `PaymentOrderDto`<br>`PaymentSignatureDto` |
| `NotificationRepository` | `MockNotificationRepository` | `GET /api/v1/notifications`<br>`PUT /api/v1/notifications/:id/read` | `NotificationItemDto` |
| `SupportRepository` | `MockSupportRepository` | `POST /api/v1/support/tickets` | `SupportTicketDto` |
| `ReviewRepository` | `MockReviewRepository` | `POST /api/v1/reviews` | `CustomerReviewDto` |
| `UrgentDispatchRepository` | `MockUrgentDispatchRepository` | `POST /api/v1/dispatch/urgent` | `UrgentDispatchRequestDto` |

---

## 3. Server-Authoritative State Machine Contracts

The Flutter client enforces that client apps **never invent or force final booking states**.
All transitions must be returned and signed by the backend.

```
                  ┌──────────────────────┐
                  │  Customer Draft      │
                  └──────────┬───────────┘
                             │ Submit Booking (Idempotent)
                             ▼
                  ┌──────────────────────┐
                  │      REQUESTED       │ ◄── Awaiting Operations / Chauffeur
                  └──────────┬───────────┘
                             │
            ┌────────────────┴────────────────┐
            ▼                                 ▼
   ┌─────────────────┐               ┌─────────────────┐
   │ DRIVER_ACCEPTED │               │    DECLINED     │
   └────────┬────────┘               └─────────────────┘
            │ Driver Starts Route
            ▼
   ┌─────────────────┐
   │ EN_ROUTE_PICKUP │
   └────────┬────────┘
            │ Driver Arrives at Venue
            ▼
   ┌─────────────────┐
   │ ARRIVED_PICKUP  │
   └────────┬────────┘
            │ Host Supplies 4-Digit OTP + Attire Check
            ▼
   ┌─────────────────┐
   │ CEREMONY_ACTIVE │
   └────────┬────────┘
            │ Ceremony Concludes
            ▼
   ┌─────────────────┐
   │    COMPLETED    │
   └─────────────────┘
```

---

## 4. Required HTTP Headers
Every outgoing HTTP request via `ApiClient` transmits:
- `Authorization: Bearer <jwt_access_token>`
- `Content-Type: application/json`
- `Accept: application/json`
- `X-Client-Version: 1.0.0`
- `X-Platform: android | ios`
- `X-Idempotency-Key: <uuid_v4>` (Required on all `POST /api/v1/bookings/submit` and payment requests)

---

## 5. Standard Error Envelope
The backend must respond with this standardized JSON payload on all 4xx and 5xx errors:
```json
{
  "success": false,
  "error": {
    "code": "INVALID_OTP",
    "message": "The entered 6-digit access code is incorrect.",
    "details": {
      "attemptsRemaining": 2
    }
  }
}
```

### Standard Error Taxonomy
- `INVALID_PHONE` — Mobile number is not a valid 10-digit Indian number.
- `OTP_EXPIRED` — Verification window (5 minutes) elapsed.
- `INVALID_OTP` — Code mismatch.
- `IDEMPOTENCY_CONFLICT` — Transaction already processed with given key.
- `CHAUFFEUR_UNAVAILABLE` — Selected driver is currently booked for overlapping ceremonial window.
- `UNAUTHORIZED` — Expired or invalid JWT token.
