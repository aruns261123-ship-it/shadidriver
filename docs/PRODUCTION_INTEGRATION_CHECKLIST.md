# ShadiDriver — Production Integration Checklist

This document is the actionable implementation runbook for connecting live backend services to the ShadiDriver Flutter mobile application.

---

## 1. Repository Swap Checklist
Replace each development mock in `lib/app/providers/app_providers.dart`:

- [ ] **1. Authentication**:
  - Implement `HttpAuthRepository` conforming to `AuthRepository`.
  - Connect to SMS Provider (e.g., Twilio / Exotel / Gupshup / AWS SNS).
  - Update `authRepositoryProvider` in `app_providers.dart`.
- [ ] **2. Bookings & State Machine**:
  - Implement `HttpBookingRepository` conforming to `BookingRepository`.
  - Connect endpoints for submission, state machine transitions, and listing.
  - Update `bookingRepositoryProvider` in `app_providers.dart`.
- [ ] **3. Chauffeur Console**:
  - Implement `HttpDriverRepository` and `HttpDriverProfileRepository`.
  - Wire WebSocket or SSE for real-time dispatch offers.
  - Update `driverRepositoryProvider` and `driverProfileRepositoryProvider`.
- [ ] **4. Trip Lifecycle**:
  - Implement `HttpTripRepository` conforming to `TripRepository`.
  - Connect milestone triggers and start OTP verification.
  - Update `tripRepositoryProvider` in `app_providers.dart`.
- [ ] **5. Route Distance & Geocoding**:
  - Implement `GoogleMapsRouteDistanceService` or `MapboxRouteDistanceService` conforming to `RouteDistanceService`.
  - Add API keys to `android/app/src/main/AndroidManifest.xml` and `ios/Runner/AppDelegate.swift`.
  - Update `routeDistanceServiceProvider` in `app_providers.dart`.
- [ ] **6. Payments & Advance Tokens**:
  - Implement `RazorpayPaymentRepository` conforming to `PaymentRepository`.
  - Set up Razorpay Flutter SDK / Cashfree Checkout.
  - Update `paymentRepositoryProvider` in `app_providers.dart`.
- [ ] **7. Push Notifications**:
  - Add `firebase_core` and `firebase_messaging` to `pubspec.yaml`.
  - Configure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
  - Update `notificationRepositoryProvider` in `app_providers.dart`.

---

## 2. Environment Variables & Secret Configuration
Create and configure `.env.production` (never commit keys to Git):

```env
API_BASE_URL=https://api.shadidriver.com/api/v1
WS_BASE_URL=wss://api.shadidriver.com/ws
RAZORPAY_KEY_ID=rzp_live_xxxxxxxx
GOOGLE_MAPS_API_KEY=AIzaSyxxxxxxxxxxxx
ENABLE_NETWORK_LOGGING=false
```

---

## 3. Pre-Release Quality Gates
Run prior to every staging and production build:

```bash
# 1. Format
dart format --set-exit-if-changed .

# 2. Analyze
flutter analyze

# 3. Test
flutter test

# 4. Release Build Verification
flutter build apk --release
flutter build appbundle --release
```
