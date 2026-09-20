# ShadiDriver Frontend Review & Roadmap

> Review date: 2026-09-20 · Scope: `frontend/` (Flutter app, all data via mock repositories)

## 1. Overall Assessment

**Health: Good.** The codebase follows a clean feature-first architecture
(`features/<name>/{domain,data,presentation}`), uses Riverpod + go_router
correctly, has a real design system in `core/`, and ships a full test suite
(241 tests, all passing). `flutter analyze` is clean. No correctness bugs were
found in this pass — the gaps were in visual fidelity and dead UI wiring, most
of which this review's companion change set fixes.

### What was fixed in this pass

| Issue | Fix |
|---|---|
| Custom fonts (Playfair Display / Plus Jakarta Sans) declared but commented out — the signature ceremonial look never rendered | Both families bundled as variable-font TTFs in `assets/fonts/`; Flutter 3.41+ maps `fontWeight` onto the `wght` axis automatically |
| Dead buttons: occasion categories, wedding packages, notification bell | Categories/packages pre-fill an occasion-filtered search; bell opens a new Notifications screen with unread badge |
| Fake content: "12 Available / ETA 8 mins" hardcoded on the urgent-dispatch card | Counts/ETA now derived from (mock) fleet availability via `urgentDispatchAvailabilityProvider` |
| "Recently Viewed" showed the last featured vehicle | Real session history — `RecentlyViewedController` tracks opened vehicles, rendered as a horizontal rail |
| `occasionId` accepted by search but ignored by the filter engine | Filter engine now matches occasions (with substring tolerance, e.g. "Royal Baraat" ↔ "Baraat"); occasion removable as a chip on results |
| No page transitions, ad-hoc spacing numbers | Fade/slide (Android/desktop) + Cupertino (iOS) transitions; `AppSpacing` token scale; theme-level snackbar/chip/tab/dialog polish; InkSparkle ripples |
| Dark theme fully built but force-disabled (`ThemeMode.light`) | Still disabled by product choice — see roadmap |

### Remaining strengths worth preserving

- **Repository seam**: every feature already programs against an abstract
  repository with a mock implementation injected in `app_providers.dart`.
  Swapping in a real backend is a provider change, not a UI rewrite.
- **Design system discipline**: `Shadi*` core widgets are reused consistently;
  new screens should keep using them instead of hand-rolling containers.
- **Test coverage of flows** (booking entry → review → result) is unusually
  good for a frontend-only project.

## 2. Roadmap (prioritized)

### P0 — Quick wins (days)

1. **Skeleton loaders** — replace `ShadiLoadingIndicator` spinners on
   home/search with shimmer skeletons shaped like the real cards. Biggest
   perceived-performance win available.
2. **Search card is static** — home's `ShadiSearchCard` renders fixed labels
   ("Delhi NCR / Nov 20, 2026 / Baraat"). Make the fields tappable, opening
   the full `SearchScreen` (or inline pickers) with the chosen values fed into
   the query.
3. **Trust section + stats** — `ShadiTrustSection` numbers (fleet size, cities)
   should come from a provider like the dispatch card now does.
4. **64dp icon-only buttons audit** — notification bell and profile shortcut in
   the app bar use default 48dp; bump visual size or add tooltips everywhere.

### P1 — Product gaps (1–2 weeks)

5. **Messages tab is an empty placeholder** — the shell routes to a static
   screen. A simple thread-list UI over a `MockConversationRepository`
   (modeled like notifications) would complete the bottom-nav promise.
6. **Occasion catalog alignment** — categories (`c1..c8`), package names, and
   `suitableCeremonies` strings are matched by substring today. Introduce a
   single `Occasion` enum/id used by all three so filtering is exact.
7. **Shortlist persistence** — `shortlistProvider` is in-memory; persist to
   secure storage so favorites survive restarts.
8. **Dark mode enablement** — `AppTheme.darkTheme` exists and is maintained;
   wire a `themeModeProvider` (system/light/dark) with a settings toggle.
   Verify contrast of champagne-on-burgundy in dark surfaces before shipping.
9. **Vehicle imagery** — every card/gallery is a placeholder icon. Even 2–3
   real images per vehicle class would transform perceived quality.
   `VehicleGallery` already handles asset/network/error paths.

### P2 — Quality & scale (ongoing)

10. **Accessibility pass** — semantic labels for icon buttons, contrast audit
    of `textTertiaryLight` on white, larger touch targets on the passenger
    counter, and TalkBack/VoiceOver walkthroughs of the booking flow.
11. **Localization (hi/en)** — strings are hardcoded English; `flutter gen-l10n`
    with ARB files, starting with the customer flow. The audience is Indian
    wedding families — Hindi support is a differentiator, not a chore.
12. **Golden tests** — the design system is stable enough to lock down with
    golden tests for core `Shadi*` widgets (light + dark, key states).
13. **Driver + admin parity** — driver dashboard/trip screens predate the
    recent customer polish; apply the same spacing tokens, transitions, and
    skeleton loaders there.
14. **Performance budget** — image caching (`cached_network_image`) once real
    images land; `const` constructor audit on hot paths; consider
    `ListView.builder` for the recently-viewed rail if catalogs grow.

### Deliberately out of scope (frontend phase)

- Payments, OTP SMS, maps/routing, push notifications — all already have
  repository interfaces and mocks; wire them when the backend exists.
- `themeMode` product decision (light-only today) — needs a design call.

## 3. How to run

```bash
cd frontend
flutter pub get
flutter analyze   # static analysis
flutter test      # 241 tests
flutter run       # mock-mode app
```
