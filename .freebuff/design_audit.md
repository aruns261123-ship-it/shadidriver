# ShadiDriver — Figma vs Flutter Visual Audit (reference = `/tmp/shadi_design/src/App.tsx` + `index.css`)

All reference measurements below are from the reference CSS (phone interior = 390×844).

## 1. Design tokens
- REFERENCE: burgundy #58111A, dark #3B0910, gold #D4AF37, warm gold #C59B27, champagne #F5E6BE, ivory #FDFBF7, paper #F7F3EC, ink #211D1B, muted #746C67, line #E7DFD5, green #1E7E34 (+soft #E7F3E9), saffron #E65100 (+soft #FFF1DF), danger #B42318 (+soft #FCE9E7); shadows `0 18px 55px rgba(59,9,16,.09)` / `0 8px 24px rgba(59,9,16,.08)`; radius scale 7/9/10/11/12/13/14/15/16/18/20/22; buttons min-height 46 (12r), card CTA 38–40; badges 26h/20r/9px uppercase; icons 24-grid, stroke ≈1.8.
- CURRENT: AppColors has brand core + Material-ish neutrals; missing paper/line/ink/muted/soft tints/danger; no ShadiSpacing/Radius/Elevation/Icons; typography scale is Material-derived (labels 11px, no 8–10px eyebrow scale).
- PLAN: new `core/theme/shadi_tokens.dart` with the full reference palette (re-exporting existing AppColors names), reference spacing/radius/elevation tokens, icon-size tokens, and the reference type scale (Playfair 34/31/29/27/22/20/19/15, Jakarta 17/15/12/11/10/9/8/7 with tracking).

## 2. Customer Home
- CURRENT: hero 305dp burgundy wash + exact copy/appbar ✓; booking panel matches (route inputs, dashed gold connector, segmented One/Both, Find Cars) ✓; categories = 105×118 tiles ✓; rails correct order ✓.
- GAPS: (a) NO photography — hero + category tiles are gradient washes, reference uses premium photos with `linear-gradient(180deg, rgba(25,8,10,.05), rgba(25,8,10,.82))` hero scrim and `linear-gradient(180deg, transparent, rgba(35,9,13,.75))` category scrim; (b) content padding 22/17 not exact.
- PLAN: bundle reference photography as Flutter assets (`assets/images/…`), a `ShadiImagery` resolver (asset-first, class-based fallback), hero + category + vehicle imagery wired; keep overflow-safe Wrap trip row (intentional deviation, documented).

## 3. Eligible Cars (results)
- CURRENT: Material AppBar (tune+sort), ActionChip filter row, "N cars eligible" line ✓, selection bar ✓ (kept).
- GAPS vs reference: appbar must be the 85px ivory `simple-appbar` (35px bordered round back, title block "Gurugram to Jaipur / One Way · 237 km", 35px round search); summary row = "18 cars eligible for your trip" + bordered pill "⚙ Filters" (7px 10px, radius 20); list cards at 15px gaps.
- PLAN: rebuild appbar as reference simple-appbar (back = pop, search = filters sheet); summary row as reference pill (filters); keep sort inside filters sheet; keep selection bar.

## 4. Vehicle card (results & home)
- CURRENT: placeholder icon image, Material title 18px, "Add to Selection" outlined full-width + full-width burgundy "View Details" button, rating/distance row — NOT reference.
- REFERENCE: photo header 150px (results) w/ heart 39px top-right + gold "Premium" badge top-left; content 18px padding; Playfair 22px title + muted 10px "SUV · 5 seats · Automatic"; green 9px trust line (14px shield); hairline top border; bottom row = eyebrow "Estimated fare" + 15px strong ₹value LEFT, burgundy 38h "Add" button RIGHT (added → champagne secondary w/ check). Compact home variant: image 120px, padding 12.
- PLAN: full rebuild of `ShadiVehicleCard` per reference geometry, PRESERVING: Hero tag, guest selection semantics (add → stepper −n+ → remove), all responsive contracts (flex/ellipsis everywhere).

## 5. Vehicle details
- CURRENT: photo header (wash) w/ back/heart/1-of-N ✓, eyebrow/title/badge/trust ✓, spec grid ✓, champagne rate card ✓, amenities ✓, sticky CTA ✓, mini-map service area ✓ (visual), Book this car now ✓.
- GAPS: photo wash (same fix as #2); minor spacing.
- PLAN: real photo into header; keep everything else.

## 6. Cart / "YOUR CARS"
- CURRENT: `GroupBookingScreen` = functional fleet builder (lines + steppers + availability + submit). Logic must be preserved verbatim.
- GAPS: visual surface is a generic form; reference cart = "YOUR CARS" + lines (name, × q, stepper, remove) + fare estimate + [Continue].
- PLAN: restage the build-stage body as the reference cart (YOUR CARS heading, per-line rows w/ steppers + Remove, fare estimate block, burgundy Continue in the bottom bar). Trip/contact fields stay (collapsed into a details card above the CTA) — controller/state untouched.

## 7. Bottom navigation
- CURRENT: 5 items (Home/Search/Bookings/Messages/Profile), Material default, no indicator.
- REFERENCE: 4 items Home/Cars/Bookings/Profile; 70px ivory translucent bar w/ blur + top hairline; 2px burgundy active indicator on top edge; 8px labels; icons 20–24.
- PLAN: rebuild shell nav to 4 reference items (Cars → search-results route; Profile keeps account center; Messages remains reachable from Profile — no route removed); style w/ indicator + exact colors; keep GuestSelectionBar stacking.

## 8. Auth
- CURRENT: crest + Playfair wordmark + "or" divider + white outlined "Continue with Google" (routes to phone flow) ✓.
- PLAN: spacing/type micro-alignment only.

## 9. Driver Fleet Home
- CURRENT: old marketplace dashboard w/ ONLINE/OFFLINE duty language and dispatch cards.
- REFERENCE: burgundy 325px header ("Good morning, Arun" / "Your fleet is ready to move."), floating ivory fleet-count card (−28 overlap, Playfair 32 count + "Manage My Cars" champagne button), metric pair AVAILABILITY/VERIFICATION (Playfair 27), "Fleet attention" card (saffron soft icon tile), "Your cars" rows (55×49 photo, name 10px, reg, two mini badges, chevron).
- PLAN: rebuild `driver_dashboard_screen` visual to the reference using REAL data: partnerRepository fleet (GET /partner/vehicles) for cars/counts/availability, chauffeur KYC store for verification counts, driver profile for the name; keep duty toggles accessible (relabel display to AVAILABLE/NOT AVAILABLE; wire values unchanged); keep navigation to trips/requests.

## 10. Driver Pricing (auto pricing)
- CURRENT: `PartnerVehiclePricingScreen` = real tariff submission form (paise wire contract, server review states) — logic preserved.
- GAPS: no reference treatment (eyebrow AUTOMATIC PRICING, Playfair "Fair pricing, calculated for you.", formula card ₹95 ÷ 8 km/L + ₹10, burgundy calculated-rate block "cannot be edited manually").
- PLAN: add reference header block + formula explainer + burgundy rate card (derived from the car's stored fuel/mileage inputs when present; sample formula otherwise) above the existing fields; keep every real field + submission path.

## 11. Driver onboarding steps
- GAPS: no visual step system. PLAN: `ShadiOnboardingSteps` widget (reference step-list: 2-col grid, champagne active w/ burgundy number, green checks) integrated into partner onboarding flow.

## 12. Super Admin
- CURRENT: mobile tabbed Scaffold (Live Dispatch / Chauffeur KYC / Fleet Registry) on live providers.
- REFERENCE: desktop shell — 232px burgundy-dark sidebar (logo, 10 nav items w/ icon+label+count pill, Aditi Kapoor/Super Admin identity block), 110px header (eyebrow OPERATIONS / DASHBOARD, title, search/bell round buttons, "Live operations" pill), KPI 4-grid (label 8 / Playfair 25 value / small note / champagne icon tile), 1.5fr/1fr ops grid (booking chart card w/ bars + 4-stat row; verification queue card w/ tinted queue icons + outline button), recent bookings 6-col table w/ status badges; Verification view = 330px queue list (champagne selected) + review panel (Under review badge, Playfair 27 title, 180×100 photo, 6 checklist rows w/ 23px circles, right-aligned Reject / Request Changes / Approve Car).
- PLAN: rebuild `admin_dashboard_screen` as a responsive desktop shell (≥1024: sidebar+grid as reference; <1024: same content stacked, sidebar hidden) wired to the EXISTING live providers (adminDashboardControllerProvider, chauffeurKycControllerProvider); real approve/reject/request-changes actions preserved; status badge language mapped to the reference set.

## 13. Status language
- GAPS: driver duty displays "ON DUTY/OFFLINE"; vehicle availability not uniformly AVAILABLE/NOT AVAILABLE; verification set must read PENDING/VERIFIED/CHANGES REQUIRED/REJECTED/SUSPENDED/DOCUMENT EXPIRED.
- PLAN: ShadiStatusBadge mapping + display-label helpers at UI layer only (wire enums untouched).

## 14. Icon fidelity
- PLAN: single outline family = Material rounded-outlined set, 20/18/16 sizes, strokeWidth 1.8 via `OutlinedIcon`-style weights; burgundy on fields, muted in labels — matching reference placement.

## Test impact
- Vehicle card rebuild → update `vehicle_card_responsive_test`, `customer_home_screen_test`, `search_results_screen_test`, `guest_browsing_test`, `guest_selection_review_test` (13/14).
- Nav 4-item → `customer_home_shell_test`.
- Driver rebuild → `driver_dashboard_screen_test` (+labels).
- Admin rebuild → `admin_dashboard_screen_test`.
- New token/imagery unit tests.
