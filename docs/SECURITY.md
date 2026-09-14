# ShadiDriver - Security, Privacy & Compliance Architecture

**Document Version:** 1.1.0  
**Status:** REFINED SECURITY & ACCESS CONTROL SPECIFICATION  
**Author:** Lead Software Architect  
**Jurisdiction:** Republic of India (DPDP Act 2023, IT Act 2000, RBI Guidelines)  

---

## 1. Security Decision Classification

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                               SECURITY DECISION CLASSIFICATION                           │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. CONFIRMED ARCHITECTURAL PRINCIPLES                                                   │
│    • Role-Based Access Control (RBAC) enforced at API Gateway and Database RLS levels    │
│    • Principle of Least Privilege across all 7 platform roles                            │
│    • Zero Raw Payment Card Storage (100% delegated to RBI-licensed payment aggregators) │
│    • Zero Raw Aadhaar Storage (Strictly masked XXXX-XXXX-1234 + encrypted tokens)       │
│    • TLS 1.3 encryption in transit enforced on all public and internal connections       │
│    • Hardware-backed keystores for mobile session tokens (Keychain / Keystore)          │
│    • Dual-sided phone number privacy masking (neither customer nor driver sees real nos) │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ 2. RECOMMENDED BUT NOT YET FINAL                                                         │
│    • Document Storage: Private AWS S3 bucket with KMS SSE and 15-minute presigned URLs   │
│    • Identity Verification Gateway: DigiLocker API / UIDAI Masking Gateway               │
│    • Masked Telephony Provider: Exotel / Twilio India Virtual Number Proxy               │
│    • Mobile Shielding: flutter_jailbreak_detection + native code obfuscation             │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ 3. BUSINESS DECISION REQUIRED                                                            │
│    • PII Data Retention Period post-account deletion (e.g. 90 days vs 3 years for tax)   │
│    • Consent & Parent/Guardian verification for minors attending wedding festivities     │
│    • Commercial background check vendor selection (IDfy vs HyperVerge vs AuthBridge)     │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ 4. FUTURE / OPTIONAL                                                                     │
│    • Biometric app re-authentication on driver pre-trip checkout                         │
│    • Certificate Pinning (HPKP) in Flutter network layer (manageable once certs stable)  │
│    • Automated SOC2 Type II and ISO 27001 formal third-party audits                      │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Comprehensive Role-Based Authorization Matrix

The platform strictly segregates capabilities across 7 roles. Every API request and database query is evaluated against these explicit permissions:

### 2.1 Role: `CUSTOMER` (Wedding Host / Event Planner)
* **Can Read**: Service catalog, ceremonial addons, real-time quotes, own profile, own bookings, assigned chauffeur profile (name, photo, vehicle plate, rating - masked phone only), live chauffeur GPS during `ARRIVING` and `TRIP_STARTED` states, own payment receipts, own reviews.
* **Can Create**: Booking requests, token payment intents, balance settlements, reviews, emergency support alerts, messages to assigned chauffeur.
* **Can Update**: Own personal profile (name, email, emergency contact), special booking instructions (prior to `DRIVER_ASSIGNED`).
* **Can Approve/Reject**: N/A (Cannot approve compliance documents or platform entities).
* **Financial Data Access**: Can view own booking invoices, quotes, and payment transaction history. Zero access to platform margins, driver payouts, or fleet commissions.
* **Personal / KYC Data Access**: Can view own PII. Chauffeur PII visible is strictly limited to first name, professional avatar, vehicle model, and registration plate.
* **Administrative Actions**: None.

### 2.2 Role: `DRIVER` (Professional Chauffeur)
* **Can Read**: Available job offers broadcast to them, assigned booking details (ceremony type, venue address, start time, dress code, family proxy contact), own profile, own document review statuses, own earnings, tips, and payout records.
* **Can Create**: Initial driver registration, KYC document uploads, pre-trip vehicle checklists, grooming selfies, trip state transition requests (`EN_ROUTE`, `ARRIVED`, `START_TRIP`, `COMPLETE_TRIP`), emergency breakdown reports.
* **Can Update**: Own profile details (sizes, spoken languages), active online/offline toggle, current GPS coordinates (via telemetry uplink).
* **Can Approve/Reject**: Can accept or decline incoming booking job offers.
* **Financial Data Access**: Can view own gross trip earnings, platform commission deductions, tips, and personal payout statuses. Zero access to customer billing cards or other drivers' earnings.
* **Personal / KYC Data Access**: Can view own uploaded documents and verification remarks. Can view customer name and venue address for assigned bookings only. Phone number is accessible strictly via masked proxy.
* **Administrative Actions**: None.

### 2.3 Role: `FLEET_OWNER` (Agency Fleet Manager - Phase 2)
* **Can Read**: Agency profile, own fleet vehicles, employed drivers, agency booking dispatch calendar, fleet-level earnings summary.
* **Can Create**: Vehicle asset profiles, vehicle document uploads, driver-vehicle roster pairings.
* **Can Update**: Agency profile, vehicle maintenance status, driver assignments to agency-accepted bookings.
* **Can Approve/Reject**: Can accept or decline incoming booking requests routed to their fleet.
* **Financial Data Access**: Can view aggregated agency revenue, platform commission withholdings, TDS tax deductions, and bank payout statuses for their fleet. Zero access to independent driver earnings or platform P&L.
* **Personal / KYC Data Access**: Can view KYC documents and employment details of drivers employed within their own fleet. Zero access to other fleets' drivers or customer private phone numbers.
* **Administrative Actions**: Internal fleet assignment only.

### 2.4 Role: `OPERATIONS_ADMIN` (Dispatch Controller)
* **Can Read**: All active bookings, live city-wide chauffeur telemetry map, fleet availability calendars, driver contact details, operational incident logs.
* **Can Create**: Assisted booking creation on behalf of VIP customers, operational notes, dispatch incident tickets.
* **Can Update**: Booking schedules (grace period extensions for delayed Baraat processions), booking status overrides during emergencies.
* **Can Approve/Reject**: N/A.
* **Financial Data Access**: Can view booking fare breakdowns and overage estimates. Cannot disburse payouts or alter commission rates.
* **Personal / KYC Data Access**: Can access unmasked customer and driver phone numbers **strictly during active emergency incidents** (all unmasking events generate a high-severity audit log).
* **Administrative Actions**: **Execute Emergency Standby Chauffeur Reassignment**, extend ceremonial grace timers, place drivers temporarily offline for investigation.

### 2.5 Role: `VERIFICATION_ADMIN` (Compliance & Trust Auditor)
* **Can Read**: Driver and vehicle KYC verification queues, uploaded document images (DL, RC, Insurance, Police NOC, Fitness), DigiLocker verification responses, past verification histories.
* **Can Create**: Verification review records, document rejection notices with specific required action items.
* **Can Update**: Document verification statuses (`APPROVED`, `REJECTED`, `ACTION_REQUIRED`), document expiration date records.
* **Can Approve/Reject**: **Can formally approve or reject driver profiles, vehicle assets, and individual compliance credentials.**
* **Financial Data Access**: Can view driver/fleet PAN card and bank account names solely to confirm name matching against the DL. Zero access to booking revenue or platform ledgers.
* **Personal / KYC Data Access**: **Full read access to uploaded identity documents** via short-lived (15-minute) presigned URLs. Masked view of Aadhaar (last 4 digits only).
* **Administrative Actions**: Suspend drivers with expired documents, initiate background re-verification audits.

### 2.6 Role: `FINANCE_ADMIN` (Accounting & Settlements Controller)
* **Can Read**: All payment records, gateway transaction logs, escrow token accounts, payout requests, refund requests, GST tax ledgers.
* **Can Create**: Payout disbursement batches, manual refund adjustments, tax debit notes.
* **Can Update**: Payout transaction statuses (`PROCESSING`, `TRANSFERRED`, `REVERSED`).
* **Can Approve/Reject**: **Can approve or decline driver and fleet payout requests and customer refund claims.**
* **Financial Data Access**: **Full read and write access to all platform financial data, gateways, payouts, and commission logs.**
* **Personal / KYC Data Access**: Can view user legal names, GSTIN, PAN, and bank IFSC details. Zero access to police verification reports or real-time location telemetry.
* **Administrative Actions**: Authorize bank batch transfers, trigger gateway refunds.

### 2.7 Role: `SUPER_ADMIN` (System Executive)
* **Can Read**: Universal read access across all platform entities and system metrics.
* **Can Create**: Admin user accounts, new service categories, new city configurations.
* **Can Update**: Dynamic pricing rules, muhurat surge multipliers, booking policies, commission structures, role assignments.
* **Can Approve/Reject**: Universal authority.
* **Financial Data Access**: Full system financial overview.
* **Personal / KYC Data Access**: Full access, governed by immutable audit logging.
* **Administrative Actions**: System policy configuration, role revocation, database maintenance, full audit log inspection.

---

## 3. Data Protection & Privacy Framework (DPDP Act 2023)

### 3.1 Masked Aadhaar & Identity Data Standard
* **Legal Invariant**: Storage of raw 12-digit Aadhaar numbers or unredacted Aadhaar physical cards is strictly forbidden under the Aadhaar Act and DPDP Act 2023.
* **Storage Standard**:
  * If Aadhaar is uploaded: Customer/driver is prompted to upload a **Masked Aadhaar** where only the last 4 digits are visible (`XXXX-XXXX-1234`).
  * Backend OCR / Verification checks reject any document where the first 8 digits are visible.
  * In the database, only `aadhaar_last_four` (VARCHAR 4) and an encrypted third-party verification reference token (`digilocker_token`) are persisted.

### 3.2 Private Telephony & Virtual Proxy Masking
* Customer and Chauffeur never exchange real phone numbers.
* Outbound calls are initiated via an in-app VoIP / PSTN virtual proxy (Exotel / Twilio).
* Both caller and receiver see the platform bridge number (`011-XXXX-XXXX`).
* The telephony bridge automatically terminates **6 hours after booking completion**.

### 3.3 Private Object Storage & Signed URLs
* All KYC and vehicle documents are stored in private cloud buckets with zero public read permissions.
* Admins view documents via short-lived presigned GET URLs with a maximum Time-To-Live (TTL) of **15 minutes**.
* Every presigned URL generation request is logged with the requesting admin’s user ID, IP address, and timestamp.
