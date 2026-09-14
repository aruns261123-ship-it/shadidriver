# ShadiDriver - Product Requirements Document (PRD)

**Document Version:** 1.0.0  
**Status:** DRAFT - PENDING ARCHITECTURAL & BUSINESS REVIEW  
**Author:** Lead Software Architect  
**Classification:** Proprietary / Confidential  

---

## 1. Executive Summary & Vision

**ShadiDriver** is a specialized, production-grade luxury mobility marketplace designed specifically for the unique demands of Indian weddings, cultural celebrations, and premium corporate events. 

Standard ride-hailing platforms (such as Uber, Ola) are fundamentally ill-suited for Indian weddings due to:
1. **Uncertainty & Cancellation Risk**: An on-demand driver cancelling 15 minutes before a *Baraat* or *Vidai* is a catastrophic failure for the host family.
2. **Lack of Ceremonial Etiquette & Protocol**: Standard drivers lack training in traditional wedding etiquette, dress codes (formal suits, safas, traditional jackets), patience during slow processions, or handling high-value family VIPs.
3. **Vehicle Quality & Presentation**: Wedding transport demands pristine, spotlessly clean luxury and executive vehicles, often requiring custom floral decor coordination and amenity kits.
4. **Complex Scheduling**: Weddings span multi-day festivities (*Haldi*, *Mehendi*, *Sangeet*, *Baraat*, *Vidai*, *Reception*) requiring scheduled multi-hour blocks, split shifts, inter-venue shuttling, and dedicated guest transport rosters.

ShadiDriver solves this by connecting discerning customers with rigorously verified professional chauffeurs and vetted luxury fleets, backed by strict service-level agreements (SLAs), emergency standby replacement protocols, and an authoritative centralized dispatch system.

---

## 2. Target Personas & User Segments

### 2.1 Customer Personas
* **The Wedding Host / Family (Bride/Groom/Parents)**: Highly stressed, emotionally invested, zero tolerance for delays or poor vehicle hygiene. Requires total peace of mind, transparent communication, and punctuality.
* **Wedding Planners & Event Management Agencies**: Power users booking multiple vehicles across multi-day itineraries. Need bulk scheduling, driver assignment manifests, real-time fleet overview, and unified corporate invoicing.
* **Corporate VIP & High-Net-Worth Individuals (HNIs)**: Demand discreet, impeccably groomed chauffeurs for executive transfers, airport VIP hospitality, and luxury gala entries.

### 2.2 Driver & Chauffeur Personas
* **Professional Chauffeur**: Experienced driver with commercial driving credentials, hospitality background, verified criminal record, and familiarity with luxury automatic/high-end vehicle handling.
* **Independent Luxury Owner-Driver**: Owns a single premium vehicle (e.g., Mercedes, BMW, Audi, Fortuner, Innova HyCross) and drives personally for high-ticket events.

### 2.3 Fleet Owners & Agency Partners
* **Fleet Operators**: Manage fleets of 5 to 50+ luxury sedans, vintage cars, and executive coaches. Require chauffeur-to-vehicle rostering, dispatch monitoring, driver payout management, and maintenance logs.

### 2.4 Internal Platform Roles
* **Verification Admin**: Scrutinizes driver identities, criminal background checks, commercial permits, vehicle inspection reports, and training certifications.
* **Operations Admin / Dispatch Controller**: Monitors active trips in real time, handles ceremony timing extensions, and manages emergency replacement chauffeurs.
* **Finance Admin**: Reconciles customer advance tokens, escrow releases, driver payouts, platform commissions, refunds, and tax compliance (GST/TDS).
* **Super Admin**: Full platform configuration, system policy management, dynamic pricing coefficients, and comprehensive audit trail inspection.

---

## 3. Core Service Categories & Use Cases

| Category ID | Service Category | Description & Operational Characteristics | Typical Vehicle Class |
| :--- | :--- | :--- | :--- |
| `SVC_BARAAT` | **Baraat Lead Chauffeur** | Procession vehicle leading the groom's party. Requires extreme driver patience for ultra-slow speeds (1–3 km/h), heavy music/firecracker tolerance, and crowd safety awareness. | Vintage / Convertible / Luxury Sedan / SUV |
| `SVC_ENTRY` | **Bride / Groom Ceremonial Entry** | Grand arrival at the mandap or banquet entry. Demands synchronized timing, immaculate exterior cleanliness, and smooth maneuvering. | Luxury Sedan (E-Class/5-Series/A6) / Vintage / Exotic |
| `SVC_VIDAI` | **Vidai Chauffeur** | Punctual, emotionally dignified post-wedding departure. Chauffeur must be present 45 minutes prior to scheduled *Vidai* muhurat without calling or disturbing the family. | Premium Sedan / Luxury SUV |
| `SVC_MULTIDAY` | **Multi-Day Wedding Package** | Dedicated chauffeur and vehicle assigned to a family for 2 to 5 days across multiple venues, airport guest pickups, and market runs. | Innova Crysta / HyCross / Premium Sedan |
| `SVC_RECEPTION` | **Reception VIP Transfer** | Scheduled evening pickup and drop for couple and key dignitaries between salon, photo studio, and banquet hall. | Executive / Luxury Sedan |
| `SVC_PHOTOSHOOT` | **Pre-Wedding Photoshoot** | Hourly rental with scenic destination navigation, accommodating multiple camera stops and dress changes. | Convertible / Vintage / Thar / Luxury Sedan |
| `SVC_GUEST_SHUTTLE`| **Guest Logistics Fleet** | Coordinated shuttling of outstation wedding guests between transit hubs, hotels, and event venues. | Tempo Traveller / Executive Coach / Multi-SUV |
| `SVC_AIRPORT_VIP` | **Airport VIP Meet & Greet** | Flight tracking, placard service at arrivals, luggage assistance, and premium transfer to wedding resort. | Premium Sedan / MPV |
| `SVC_URGENT_DISPATCH`| **Urgent Chauffeur Dispatch** | Emergency replacement chauffeur deployed within tight SLA when an external driver fails to show up on the wedding day. | Standby Pool (All Categories) |

---

## 4. Ceremonial Add-ons & Customizations

Customers can customize the chauffeur experience to align with wedding themes and traditions:

1. **Chauffeur Ceremonial Attire**:
   * Standard Executive: Dark formal two-piece suit with tie.
   * Traditional Royal: Bandhgala / Jodhpuri suit with ceremonial Safa/Turban (color coordinated with groom/bride theme).
   * White Traditional: Crisp white Kurta-Pyjama with Nehru jacket.
2. **Vehicle Floral Decor Coordination**:
   * Integration with the wedding florist (providing vehicle access windows and floral tie-down guidelines to prevent paint damage).
3. **In-Cabin Amenity Kit**:
   * Packaged mineral water bottles, mints, wet wipes, hand sanitizers, umbrella, phone chargers (Type-C, Lightning), and first-aid box.
4. **Bilingual / Regional Protocol**:
   * Chauffeur proficient in specific languages (e.g., Hindi, Punjabi, Gujarati, Marwari, English) for comfortable family interaction.
5. **Red Carpet Entry Protocol**:
   * Chauffeur trained in door-opening etiquette, umbrella assistance during monsoon/summer arrivals, and luggage handling.

---

## 5. Functional Requirements by Role

### 5.1 Customer App (Mobile: iOS & Android)
* **Onboarding & Auth**: Phone OTP authentication; profile management with family contact details.
* **Service Discovery**: Browse service categories, vehicle tiers, ceremonial packages, and transparent pricing estimates.
* **Custom Booking Builder**:
  * Event date(s), start time, estimated duration, multi-stop itinerary.
  * Chauffeur attire selection, linguistic preference, and ceremonial add-ons.
  * Vehicle class selection or dedicated chauffeur-only booking (customer's own vehicle).
* **Booking Management**: Real-time status tracker, event timeline view, chauffeur profile (photo, verified badge, rating, contact via proxy).
* **Live Telemetry & Tracking**: Live GPS tracking during `DRIVER_ARRIVING` and active `TRIP_STARTED` states.
* **Secure Payments**: Advance token payment, balance escrow settlement, tips, and automated GST invoice download.
* **Safety & Support**: Direct SOS button, masked in-app calling to chauffeur, 24/7 wedding concierge hotline.
* **Ratings & Feedback**: Post-ceremony review capturing chauffeur punctuality, etiquette, vehicle cleanliness, and driving smoothness.

### 5.2 Driver App (Mobile: Android & iOS)
* **KYC & Onboarding**: Digital document submission (DL, Aadhaar, Police Verification, Chauffeur certification, vehicle papers).
* **Roster & Job Management**: View incoming job requests with ceremony type, location, dress code, and payout details.
* **Event Briefing**: Step-by-step ceremony itinerary, family contact proxy, venue entry gate instructions, and floral decor coordinates.
* **Pre-Trip Inspection Checklist**: Digital attestation of fuel level, vehicle cleanliness, AC functioning, tyre pressure, and dress code selfie before dispatch.
* **Real-time Navigation & State Transitions**: State transition controls (`START_TO_PICKUP`, `ARRIVED_AT_VENUE`, `START_CEREMONY`, `COMPLETE_SERVICE`).
* **Emergency Assistance**: Driver panic button, breakdown reporting, and automatic operations control notification.
* **Earnings & Payout Ledger**: Transparent breakdown of base fare, hourly overage, night allowances, tips, and payout withdrawal status.

### 5.3 Fleet Owner Portal (Web & Tablet Responsive)
* **Fleet & Driver Roster**: Add/manage vehicles and drivers; track document expiration dates.
* **Manual Assignment**: Assign internal verified chauffeurs to accepted booking requests.
* **Live Fleet Telemetry**: Live map view of all active vehicles across ongoing wedding bookings.
* **Financial Settlements**: Fleet-level earnings summary, commission deductions, and automated payout ledger.

### 5.4 Operations & Admin Control Room (Web Dashboard)
* **Verification Pipeline**: Review driver and vehicle documents, verify identity against official registries, approve/reject applications.
* **Live Dispatch Control Room**: Real-time map displaying all active wedding events, driver statuses, and telemetry health.
* **Emergency Chauffeur Reassignment**: Single-click manual or algorithmic reassignment of standby chauffeurs in case of vehicle breakdown or driver delay.
* **Pricing & Policy Engine**: Configure base rates, hourly overages, muhurat surge multipliers, cancellation grace windows, and deposit token rules.
* **Dispute & Support Mediation**: Access audit logs, chat logs, GPS history, and payment transactions for dispute resolution.

---

## 6. Non-Functional Requirements (NFRs)

### 6.1 Reliability & Availability
* **Target Uptime**: 99.95% availability, especially during peak Indian wedding season (October to March).
* **Graceful Degradation**: Offline-first local persistence in the Driver App to ensure trip recording functions even in underground banquet halls or remote farmhouses with zero cellular reception.

### 6.2 Latency & Performance
* **Telemetry Streaming**: Real-time vehicle location updates pushed to customer UI with `< 3 seconds` end-to-end latency under normal 4G/5G conditions.
* **App Cold Start**: Cold start to interactive dashboard `< 2.0 seconds` on mid-tier Android devices (e.g., Snapdragon 600 series).

### 6.3 Security, Privacy & Data Compliance
* **Regulatory Compliance**: Full adherence to India’s **Digital Personal Data Protection (DPDP) Act 2023**.
* **Identity Protection**: Zero plain-text storage of Aadhaar numbers. Strict integration with UIDAI-compliant masking or DigiLocker verification APIs.
* **Communication Privacy**: Dual-sided phone number masking (virtual proxy) to prevent drivers or customers from accessing private phone numbers post-event.
* **Storage Encryption**: AES-256 encryption at rest for sensitive PII and financial records; TLS 1.3 enforced for all transport.

---

## 7. Open Questions & Unresolved Business Decisions

> [!IMPORTANT]
> The following commercial, legal, and operational policies must be formally resolved by the business leadership prior to production feature implementation:

1. `[UNRESOLVED BUSINESS DECISION]` **Advance Token Structure**:
   * *Option A*: Fixed percentage token (e.g., 20% at booking, 80% 24 hours prior to event).
   * *Option B*: Flat registration deposit based on vehicle category.
   * *Option C*: 100% full upfront escrow payment.
2. `[UNRESOLVED BUSINESS DECISION]` **Baraat Damage & Firecracker Liability**:
   * How are damages from Baraat smoke bombs, fireworks, or unruly procession dancers handled? Does ShadiDriver require a mandatory refundable security deposit from the customer, or an add-on event insurance policy?
3. `[UNRESOLVED BUSINESS DECISION]` **Chauffeur Overtime & Delays**:
   * Indian weddings notoriously run 2 to 4 hours behind schedule. What is the exact overage billing calculation (per 30-minute block vs per hour)? At what point is an exhausted chauffeur legally required to be replaced by a relief driver for safety?
4. `[UNRESOLVED BUSINESS DECISION]` **Chauffeur Ceremonial Uniform Sourcing**:
   * Does the platform supply branded Jodhpuri suits and safas to verified chauffeurs (capex/deposit model), or do chauffeurs purchase their own uniforms meeting prescribed quality guidelines?
5. `[UNRESOLVED BUSINESS DECISION]` **Cancellation Grace Windows**:
   * Wedding dates cannot be easily re-booked last-minute. What is the non-refundable window? (e.g., 100% refund if >30 days before wedding, 50% if 7–30 days, 0% if <7 days).
6. `[UNRESOLVED BUSINESS DECISION]` **Commission & Take-Rate**:
   * Percentage commission on independent drivers vs fleet operators vs chauffeur-only service.
