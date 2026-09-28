# Vehicle-First Product Model — Foundation Audit (Slice 15)

Scope: the "first implementation slice" of the vehicle-first redesign — audit the
current domain against the target product model, fix genuine gaps, change nothing
that already works. Baseline: guest-first entry slice (verified on device).

---

## A. Current domain model (as implemented)

| Product concept | Implementation | State |
|---|---|---|
| Partner (multi-vehicle owner) | `PartnerProfile` (`fleet_owners`): company + KYC + professional details + own `verificationStatus`; `vehicles Vehicle[]` — one partner, many vehicles | ✅ complete |
| Chauffeur | `DriverProfile` (`drivers`), own verification lifecycle; linked to partner via `fleetOwnerId` | ✅ complete |
| Vehicle (the bookable object) | `Vehicle`: type, year, color, registration (unique), fuel, transmission, AC, vintage, city, `photoUrls[]`, `amenityTags[]`, `serviceAreas[]`, own `verificationStatus`, `isAvailable`, `isActive`; owner = `independentDriverId` **or** `fleetOwnerId` (never both required) | ✅ complete |
| Vehicle documents | `VehicleDocument` — `VehicleDocumentType`: RC, commercial insurance, PUC, fitness, commercial permit, vehicle tax; review state per document | ✅ complete |
| Partner documents | `PartnerDocument` — identity, licence, trade licence, etc. | ✅ complete |
| Per-vehicle tariff | `VehiclePricing` — versioned (`@@unique([vehicleId, version])`), local/per-km/hourly/extra-hour/full-day/overnight/outstation-per-day/outstation-per-km fields, `PricingStatus` lifecycle + admin decision trail | ✅ complete |
| Customer favorite | `FavoriteVehicle` (Customer → FavoriteVehicle → Vehicle) | ✅ complete |
| Booking request | `GroupBooking` (managed path): customer, ceremony, city, addresses, service window, `requestedFleetItems` [{vehicleTypeId, quantity, vehicleClass}], passengerCount, requirements, communicationPreference, quote + immutable `pricingSnapshot`, `advancePaidAt`/`balancePaidAt`, `startOtpHash` | ✅ complete |
| Lifecycle | `BookingStatus`: DRAFT → REQUESTED → UNDER_REVIEW → VEHICLE_OPTIONS_PREPARED → CUSTOMER_CONFIRMATION_PENDING → CONFIRMED → IN_PROGRESS → COMPLETED (+ CANCELLED, EXPIRED, PAYMENT_PENDING, PAYMENT_FAILED) — backend-authoritative via `BookingStateMachineService` | ✅ complete |
| Allocation | `VehicleAssignment` — GroupBooking → actual `vehicleId` + nullable `driverId`, sequence, per-assignment pricing snapshot, ops-actor trail; `AssignmentStatus` ladder (vehicle confirmed → chauffeur assigned → executed) with NO customer-facing offer loop | ✅ complete |
| Operations audit | `GroupBookingEvent` (every transition, actor, role) + `OperationsNote` (admin-only) + `AuditLog` | ✅ complete |
| Reviews | `Review` — bookingId (legacy) / groupBookingId+assignmentId (managed), vehicle + optional chauffeur FK, 6 rating dimensions, moderation (`ReviewStatus`) | ✅ complete |
| Payments | `Payment` — attachable to legacy booking OR group booking; 25% advance / balance on group path; gateway-abstracted, webhook dual-routing | ✅ complete |
| Verification model | Shared `VerificationStatus` enum: PENDING_SUBMISSION, SUBMITTED, UNDER_REVIEW, APPROVED, ACTION_REQUIRED, REJECTED, SUSPENDED, DOCUMENT_EXPIRED — partner and vehicle verified **separately** (separate columns, separate admin queues) | ✅ complete |

## B. Required domain changes → none outstanding

Every relationship the product model requires already exists and is enforced in
services:

- **Partner owns many vehicles** — `PartnerProfile.vehicles`; partner onboarding
  slice (5) + fleet CRUD verified live earlier.
- **Vehicle-first bookable object** — customers request vehicle TYPES
  (`requestedFleetItems`); operations allocates ACTUAL vehicles
  (`VehicleAssignment.vehicleId`) from any partner. Customers never choose (or
  see) the partner.
- **Chauffeur invisible to customers** — `driverId` nullable until ops assigns;
  customer serializer (`serializeCustomerGroupBooking`) collapses assignments to
  neutral status; chauffeur identity never enters a customer payload.
- **Only verified + active vehicles bookable** — public listing filters
  `verificationStatus: 'APPROVED' AND isActive AND isAvailable` (vehicles.service).
- **Pricing pipeline** — partner tariff → `PENDING_REVIEW` → admin approve →
  `APPROVED` → server derives quote (`group-booking-pricing.ts`) → booking stores
  immutable `pricingSnapshot`; later tariff edits create a NEW version and
  `SUPERSEDE` the old one — confirmed bookings never re-price.
- **Reviews only after completion** — managed reviews require assignment
  `COMPLETED` and group `COMPLETED`; DB-unique per (group booking, vehicle).

## C. Database changes → drift fixed this slice

`prisma migrate diff` (live DB → schema) reported three drifts, all declaration
gaps in `schema.prisma` (the DATABASE was always correct — created by migration
20260925220000/20260925230000). **Fixed by declaring what the DB already has:**

1. `Review`: `@@unique([groupBookingId, vehicleFk], map: "reviews_group_booking_vehicle_unique")`
   — the DB-enforced duplicate-review guard was missing from the schema.
2. `Payment`: FK delete actions corrected to match reality — `bookingId →
   onDelete: Restrict`, `groupBookingId → onDelete: Cascade`; missing
   `@@index([groupBookingId])` declared.
3. `Review.booking` relation → `onDelete: Restrict`.

Post-fix `migrate diff` output: **"This is an empty migration."** — schema and
database are byte-equivalent in intent. No new migration needed; no data risk.

## D. API changes → none required

Existing contract surface already implements the model (all verified live in
prior slices):

- **Public (guest):** `GET /vehicles`, `/vehicles/types`, `/vehicles/availability`,
  `/vehicles/:id` — `@Public()`, customer-safe DTO only.
- **Customer:** group booking submit/availability/my/detail/transition, trip OTP,
  payments group order/verify/history, reviews, favorites.
- **Operations:** queue, workspace, transitions, contact log, re-quote, notes,
  chauffeur picker, re-allocation, unassign.
- **Admin:** verification center (partner/vehicle/pricing), audit.

## E. Customer-safe vs admin-safe DTO boundary → already enforced at backend

- `vehicles.public-dto.spec.ts` proves the public vehicle payload never contains
  driver identity, phone, avatar, registration plate, or document details
  (`vehicles.service.ts` selects only `verificationStatus` from the driver
  relation; partner relation selects ids only).
- `serializeCustomerGroupBooking` is the single customer serializer for group
  bookings (snake_case, quote-safe, no chauffeur PII); ops workspace returns the
  full internal allocation through a separate service path.
- Internal notes are ops-only (`OperationsNote` never returned to customers).

## F. Partner onboarding → implemented (slice 4/5)

Registration → OTP → professional info → fleet CRUD → documents → photos →
pricing submission → verification submission, each step behind
`backend/src/partner/` with role-guarded endpoints. Admin approval flows in
`backend/src/admin/`. Flutter partner UI remains the outstanding (API-first was a
deliberate earlier decision).

## G. Admin changes → backend complete; admin Flutter UI pending

Operations queue/workspace/notes/audit + verification center + pricing approval
exist as verified APIs. The admin dashboard UI (information-dense queue screens)
is the known pending surface — tracked as its own slice, not part of this
foundation.

## H. Migration risks → none introduced

This slice wrote NO migration (drift was schema-side). The schema edits are
declaration-only and validated by `prisma validate` + empty-diff proof. Future
slices that DO migrate should watch:

- `payments_booking_id_fkey` is RESTRICT — deleting a legacy booking with
  payments will fail (intentional financial audit protection).
- The review unique guard means the reviews service must upsert, not blind-insert,
  on replay.

---

## Verification performed this slice

- `prisma validate` ✅ · `prisma generate` ✅ · live-DB diff = empty ✅
- Full backend suite: **444 unit + 125 e2e green**, eslint `--max-warnings=0`,
  `tsc --noEmit`, `nest build` ✅
- Frontend: analyze clean, **452 tests green** (guest-first behavior preserved)
