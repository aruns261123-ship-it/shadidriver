# ShadiDriver - Architectural Decision Log (ADR)

**Document Version:** 1.0.0  
**Status:** ACTIVE LIVING DOCUMENT  
**Author:** Lead Software Architect  

---

## 1. Decision Log Index

| ID | Decision Title | Status | Impact Area |
| :--- | :--- | :--- | :--- |
| **ADR-001** | Feature-First Clean Architecture | **CONFIRMED** | Flutter Client Architecture |
| **ADR-002** | Riverpod 2.x for Application State | **CONFIRMED** | Flutter State Management |
| **ADR-003** | GoRouter for Declarative Navigation & Guards | **CONFIRMED** | Client Routing & Security |
| **ADR-004** | Freezed & json_serializable for Immutability | **CONFIRMED** | Data Modeling |
| **ADR-005** | Dio Abstraction & Repository Interfaces | **CONFIRMED** | Network & Decoupling |
| **ADR-006** | Server-Authoritative State Machine & Optimistic Locking | **CONFIRMED** | Core Transactional Logic |
| **ADR-007** | Configurable Dynamic Pricing & Policy Engine | **CONFIRMED** | Commercial Logic |
| **ADR-008** | Supabase (PostgreSQL 16 + PostGIS) for MVP Backend | **RECOMMENDED BUT NOT FINAL** | Backend Infrastructure |
| **ADR-009** | Cloud Hosting Region: Mumbai (ap-south-1 / asia-south1) | **RECOMMENDED BUT NOT FINAL** | Cloud Infrastructure |
| **ADR-010** | Time-Ordered UUIDv7 for Distributed Primary Keys | **RECOMMENDED BUT NOT FINAL** | Database Performance |
| **ADR-011** | Private S3 / Cloud Storage with Presigned URLs for KYC | **RECOMMENDED BUT NOT FINAL** | Document Vault Security |
| **ADR-012** | Masked Aadhaar Storage & DigiLocker Gateway | **RECOMMENDED BUT NOT FINAL** | DPDP Compliance |
| **ADR-013** | Payment Gateway: Razorpay / Cashfree | **RECOMMENDED BUT NOT FINAL** | Payments & Settlements |
| **ADR-014** | Dual-Sided Telephony Masking via CPaaS Proxy | **RECOMMENDED BUT NOT FINAL** | Privacy & Safety |
| **ADR-015** | Advance Token Deposit Model (Commercial Terms) | **BUSINESS DECISION REQUIRED** | Commercial Policy |
| **ADR-016** | Baraat Firecracker Damage Liability & Security Deposit | **BUSINESS DECISION REQUIRED** | Legal & Risk Management |
| **ADR-017** | Double-Entry Escrow Ledger Phasing (Phase 3+) | **FUTURE / OPTIONAL** | Accounting Infrastructure |
| **ADR-018** | Transition from Modular Monolith to Microservices | **FUTURE / OPTIONAL** | Long-Term Scalability |
| **ADR-019** | Application Package & Bundle Identity Migration | **RECOMMENDED BUT NOT FINAL** | Platform & Store Identity |

---

## 2. Detailed Architectural Decision Records

### ADR-001: Feature-First Clean Architecture
* **Status**: **CONFIRMED ARCHITECTURAL PRINCIPLE**
* **Rationale**: Wedding mobility is a complex domain spanning booking engines, real-time tracking, driver KYC, and operations control. Partitioning code by feature slices (`features/booking`, `features/verification`, `features/catalog`) with strict layer isolation (`presentation`, `domain`, `data`) ensures high maintainability, independent team scaling, and isolated refactoring.
* **Alternatives Considered**: Layer-first architecture (all controllers together, all screens together); Flat MVC structure. Both lead to massive circular dependencies as the app scales beyond 10 screens.
* **Dependencies**: Domain layer must remain pure Dart with zero Flutter UI imports.
* **What Would Cause Revisit**: Never; this is foundational to production-grade Flutter engineering.

---

### ADR-002: Riverpod 2.x for Application State Management
* **Status**: **CONFIRMED ARCHITECTURAL PRINCIPLE**
* **Rationale**: Riverpod offers compile-time safety, seamless asynchronous state handling via `AsyncNotifier` / `AsyncValue`, testability without `BuildContext`, and clear dependency injection boundaries.
* **Alternatives Considered**: Bloc/Cubit (more verbose boilerplate); Provider (runtime lookup errors); GetX (anti-pattern, global untestable state).
* **Dependencies**: `flutter_riverpod`, `riverpod_annotation`.
* **What Would Cause Revisit**: Deprecation of Dart or emergence of an officially blessed Flutter reactive state standard with equal compile-time guarantees.

---

### ADR-003: GoRouter for Declarative Navigation & Guards
* **Status**: **CONFIRMED ARCHITECTURAL PRINCIPLE**
* **Rationale**: Provides declarative URL-based routing necessary for deep links (e.g. `/bookings/{id}` sent via SMS/WhatsApp), nested shell routes for role dashboards, and synchronous `redirect` route guards that inspect authentication and verification states before rendering.
* **Alternatives Considered**: Navigator 2.0 raw RouterDelegate (excessively complex); AutoRoute (heavy code generation).
* **Dependencies**: Riverpod auth state provider.
* **What Would Cause Revisit**: Significant breaking changes or deprecation by the Flutter core team.

---

### ADR-004: Freezed & json_serializable for Immutability
* **Status**: **CONFIRMED ARCHITECTURAL PRINCIPLE**
* **Rationale**: Eliminates object mutation bugs across booking states. Discriminated unions allow compile-time exhaustive pattern matching over booking states and async states.
* **Alternatives Considered**: Equatable with manual copyWith methods (tedious, error-prone boilerplate); BuiltValue (cumbersome syntax).
* **Dependencies**: `freezed_annotation`, `build_runner`.
* **What Would Cause Revisit**: Native Dart language addition of data classes and pattern matching unions that make external codegen redundant.

---

### ADR-005: Dio Abstraction & Repository Interfaces
* **Status**: **CONFIRMED ARCHITECTURAL PRINCIPLE**
* **Rationale**: Domain layers define abstract repository interfaces (`BookingRepository`). The presentation layer only consumes these interfaces. `Dio` is encapsulated in `data/` data sources, enabling seamless swapping of mock repositories during tests or swapping REST for WebSockets/gRPC without touching UI widgets.
* **Alternatives Considered**: `http` package (lacks interceptors, cancel tokens, and global error normalization).
* **Dependencies**: Clean Architecture layer boundaries.
* **What Would Cause Revisit**: Native Dart HTTP client adopting full interceptor pipelines with cancellation support.

---

### ADR-006: Server-Authoritative State Machine & Optimistic Locking
* **Status**: **CONFIRMED ARCHITECTURAL PRINCIPLE**
* **Rationale**: High-stakes wedding transportation cannot tolerate race conditions, accidental double-bookings, or rogue client state overrides. The server is the sole arbiter of state transitions using database atomic transactions and optimistic concurrency (`version` column).
* **Alternatives Considered**: Client-authoritative sync (unacceptable risk of double-booking or fraud).
* **Dependencies**: Relational database with transaction isolation.
* **What Would Cause Revisit**: Never; server authority is a core security invariant.

---

### ADR-007: Configurable Dynamic Pricing & Policy Engine
* **Status**: **CONFIRMED ARCHITECTURAL PRINCIPLE**
* **Rationale**: Commercial rates, cancellation penalty percentages, and peak *muhurat* date multipliers change frequently across cities and wedding seasons. Hard-coding them into client or server code requires redeployments. Storing them in `pricing_rules` and `booking_policies` enables instant business adjustments.
* **Alternatives Considered**: Hardcoded configuration constants.
* **Dependencies**: Database seed scripts and Super Admin policy console.
* **What Would Cause Revisit**: Never.

---

### ADR-008: Supabase (PostgreSQL 16 + PostGIS) for MVP Backend
* **Status**: **RECOMMENDED BUT NOT YET FINAL**
* **Rationale**: Cuts 6–8 weeks of infrastructure boilerplate by providing instant Auth, REST/Realtime APIs, PostGIS spatial queries, and Row-Level Security on top of pure open-source PostgreSQL. Unlike Firebase, it enforces relational integrity and ACID transactions. Unlike a custom backend, it requires zero server setup for MVP.
* **Alternatives Considered**: Firebase (NoSQL lacks ACID for bookings/escrow; poor geospatial query model); Custom Go/Node backend (Adds 2 months of dev time before pilot).
* **Dependencies**: Client Repository interfaces decoupling UI from Supabase SDK.
* **What Would Cause Revisit**: Extreme customization requirements in dispatch queuing or high-volume real-time WebSocket connection limits that mandate a dedicated Go microservice.

---

### ADR-009: Cloud Hosting Region: Mumbai (ap-south-1 / asia-south1)
* **Status**: **RECOMMENDED BUT NOT YET FINAL**
* **Rationale**: Compliance with India's DPDP Act 2023 regarding data residency and minimizing network latency (<30ms) across Indian metropolitan areas (Delhi NCR, Jaipur, Mumbai).
* **Alternatives Considered**: Singapore / US East (higher latency, regulatory scrutiny).
* **Dependencies**: Cloud provider availability.
* **What Would Cause Revisit**: Mandate from government authorities requiring specific on-premises or state data center hosting.

---

### ADR-010: Time-Ordered UUIDv7 for Distributed Primary Keys
* **Status**: **RECOMMENDED BUT NOT YET FINAL**
* **Rationale**: Combines 48-bit Unix timestamp with random entropy. Time-ordering prevents B-Tree index page splitting during high-volume booking spikes, while preserving universal uniqueness across distributed clients.
* **Alternatives Considered**: UUIDv4 (causes index fragmentation); Auto-incrementing BigInt (leaks business metrics and volume to competitors).
* **Dependencies**: Database extension or application-level UUID generator.
* **What Would Cause Revisit**: If target database lacks native UUIDv7 support and application-level generation adds unacceptable overhead, fallback to standard UUIDv4.

---

### ADR-011: Private S3 / Cloud Storage with Presigned URLs for KYC
* **Status**: **RECOMMENDED BUT NOT YET FINAL**
* **Rationale**: Chauffeur driving licences and vehicle registration papers are sensitive personal records. Storing them in private buckets with public access completely blocked and generating short-lived (15-minute) presigned GET URLs ensures zero unauthorized indexing or leakage.
* **Alternatives Considered**: Public storage with randomized URLs (security vulnerability; violates DPDP Act).
* **Dependencies**: Cloud storage IAM and KMS configuration.
* **What Would Cause Revisit**: None, unless self-hosted private blob storage is mandated.

---

### ADR-012: Masked Aadhaar Storage & DigiLocker Gateway
* **Status**: **RECOMMENDED BUT NOT YET FINAL**
* **Rationale**: Storing raw 12-digit Aadhaar numbers carries severe legal penalties under the Aadhaar Act. Capturing masked Aadhaar (`XXXX-XXXX-1234`) and verifying credentials via government DigiLocker API or licensed KYC aggregators (HyperVerge / IDfy) ensures full legal compliance.
* **Alternatives Considered**: Direct raw Aadhaar capture (illegal in India without Aadhaar Vault license).
* **Dependencies**: Third-party KYC vendor API contract.
* **What Would Cause Revisit**: Changes in UIDAI / Ministry of Electronics and Information Technology (MeitY) guidelines.

---

### ADR-013: Payment Gateway: Razorpay / Cashfree
* **Status**: **RECOMMENDED BUT NOT YET FINAL**
* **Rationale**: Market leaders in India with native support for UPI AutoPay, credit card tokenization compliant with RBI mandates, and robust escrow/split-payment capabilities for driver disbursements.
* **Alternatives Considered**: Stripe India (restricted onboarding for domestic Indian businesses); PayU.
* **Dependencies**: Legal entity merchant onboarding and KYC.
* **What Would Cause Revisit**: Unfavorable commercial take-rate negotiations or technical downtime.

---

### ADR-014: Dual-Sided Telephony Masking via CPaaS Proxy
* **Status**: **RECOMMENDED BUT NOT YET FINAL**
* **Rationale**: Protects customer and chauffeur privacy by bridging calls through virtual proxy numbers (Exotel / Twilio). Neither party discovers the other's personal mobile number.
* **Alternatives Considered**: Direct unmasked phone calling (high risk of off-platform poaching and customer harassment); In-app WebRTC VoIP (unreliable over weak 4G/3G in rural banquet farmhouses).
* **Dependencies**: CPaaS virtual number procurement.
* **What Would Cause Revisit**: Excessive telephony per-minute costs for pilot phase (can temporarily fall back to human dispatcher relay).

---

### ADR-015: Advance Token Deposit Model
* **Status**: **BUSINESS DECISION REQUIRED**
* **Rationale**: Weddings require guaranteed vehicle availability. Advance deposits prevent last-minute customer cancellations while securing driver commitment. The exact structure (20% vs 50% vs 100% upfront) impacts checkout conversion and cash flow.
* **Alternatives Considered**: Full payment upfront; Zero deposit with cash on arrival.
* **Dependencies**: Executive commercial committee decision.
* **What Would Cause Revisit**: Formal executive sign-off on commercial terms.

---

### ADR-016: Baraat Firecracker Damage Liability & Security Deposit
* **Status**: **BUSINESS DECISION REQUIRED**
* **Rationale**: Baraat processions involve heavy fireworks, dancing on vehicle roofs, and smoke bombs that can damage expensive luxury car paint and convertibles. Platform must decide whether to require a refundable damage deposit from the host or partner with an insurer for transit event insurance.
* **Alternatives Considered**: Chauffeur absorbs risk (deters luxury car owners); Platform absorbs risk (unsustainable loss ratio).
* **Dependencies**: Legal counsel and commercial insurance broker review.
* **What Would Cause Revisit**: Formal insurance underwriting agreement or terms of service sign-off.

---

### ADR-017: Double-Entry Escrow Ledger Phasing (Phase 3+)
* **Status**: **FUTURE / OPTIONAL**
* **Rationale**: While a full double-entry accounting ledger (`wallets`, `ledger_accounts`, `debit_credit_entries`) is the gold standard for fintech, implementing it for a single-city MVP pilot creates excessive engineering overhead. MVP relies on transaction status reconciliation in `payments` and `payouts` tables.
* **Alternatives Considered**: Building full ledger in Phase 1 (delays launch by 4 weeks).
* **Dependencies**: Scale reaching >1,000 bookings/month.
* **What Would Cause Revisit**: Reaching financial scale where automated multi-party splits and daily bank reconciliation audits become legally required.

---

### ADR-018: Transition from Modular Monolith to Microservices
* **Status**: **FUTURE / OPTIONAL**
* **Rationale**: The backend starts as a cleanly partitioned Modular Monolith sharing a single PostgreSQL database. Prematurely splitting into independent microservices introduces distributed transaction complexity, network overhead, and DevOps drag during MVP.
* **Alternatives Considered**: Day-1 microservices architecture.
* **Dependencies**: Scale exceeding 10,000 active concurrent drivers or distinct engineering teams needing autonomous deployment pipelines.
* **What Would Cause Revisit**: When individual services (e.g. Telemetry Ingestion vs Booking State Machine) have drastically asymmetric CPU/memory scaling profiles.

---

### ADR-019: Application Package & Bundle Identity Migration
* **Status**: **ACCEPTED & IMPLEMENTED**
* **Decision**: Adopt universal bundle identity `in.shadidriver.app` across Android (`namespace` and `applicationId`), iOS, macOS, and Linux platforms.
* **Rationale**: The repository was generated with placeholder identifier `com.example.shadidriver`. Production Google Play Console and Apple Developer accounts require an authoritative, registered reverse-domain identity. Single multi-role app bundle architecture with server-authoritative role determination utilizes `in.shadidriver.app`.
* **Implementation Details**:
  - Android namespace & applicationId: `in.shadidriver.app`
  - Android Kotlin Package: `in.shadidriver.app.MainActivity`
  - iOS/macOS Bundle Identifier: `in.shadidriver.app`
  - Linux Application ID: `in.shadidriver.app`

