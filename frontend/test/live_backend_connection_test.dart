import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/config/flavor.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/auth/data/auth_api_repository.dart';
import 'package:shadidriver/features/auth/domain/entities/user_role.dart';
import 'package:shadidriver/features/bookings/data/booking_api_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/core/constants/app_constants.dart';
import 'package:shadidriver/features/services/data/service_category_api_repository.dart';
import 'package:shadidriver/features/vehicles/data/vehicle_api_repository.dart';

class InMemorySecureStorage implements SecureStorageService {
  final Map<String, String> _storage = {};
  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);
  @override
  Future<void> delete(String key) async => _storage.remove(key);
  @override
  Future<void> deleteAll() async => _storage.clear();
  @override
  Future<String?> read(String key) async => _storage[key];
  @override
  Future<void> write(String key, String value) async => _storage[key] = value;
}

class SilentTestLogger implements AppLogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {}
}

void main() {
  group('End-to-End Live Backend Connection Test', () {
    const config = EnvironmentConfig(
      flavor: AppFlavor.development,
      appName: 'ShadiDriver Dev',
      apiBaseUrl: 'http://localhost:3000',
      wsBaseUrl: 'ws://localhost:3000',
      useMockData: false,
    );

    late InMemorySecureStorage storage;
    late ApiClient client;
    late VehicleApiRepository vehicleRepo;
    late ServiceCategoryApiRepository categoryRepo;
    late AuthApiRepository authRepo;
    late BookingApiRepository bookingRepo;

    setUpAll(() {
      storage = InMemorySecureStorage();
      client = ApiClient(
        config: config,
        logger: SilentTestLogger(),
        secureStorage: storage,
      );
      vehicleRepo = VehicleApiRepository(client);
      categoryRepo = ServiceCategoryApiRepository(client);
      authRepo = AuthApiRepository(client, storage);
      bookingRepo = BookingApiRepository(client);
    });

    test('1. Backend Health Check — Database and NestJS API is operational', () async {
      final healthRes = await client.get('/api/v1/health/ready');
      expect(healthRes.statusCode, 200);
      final envelope = healthRes.data as Map<String, dynamic>;
      expect(envelope['success'], true);
      expect((envelope['data'] as Map)['status'], 'ok');
      expect((envelope['data'] as Map)['database'], 'up');
    });

    test('2. Vehicle Catalog & Details — PostgreSQL real fleet data', () async {
      // 2A. Featured vehicles
      final featuredResult = await vehicleRepo.getFeaturedVehicles();
      expect(featuredResult.isSuccess, true, reason: 'Featured vehicles fetch must succeed');
      final vehicles = featuredResult.dataOrNull!;
      expect(vehicles.isNotEmpty, true, reason: 'At least 1 vehicle must be seeded');

      final firstVehicle = vehicles.first;
      expect(firstVehicle.id.isNotEmpty, true);
      expect(firstVehicle.make.isNotEmpty, true);
      expect(firstVehicle.model.isNotEmpty, true);
      expect(firstVehicle.pricing.basePriceCents, greaterThan(0));

      // 2B. Detailed vehicle lookup
      final detailsResult = await vehicleRepo.getVehicleDetails(firstVehicle.id);
      expect(detailsResult.isSuccess, true, reason: 'Vehicle details fetch must succeed');
      final details = detailsResult.dataOrNull!;
      expect(details.id, firstVehicle.id);
      expect(details.make, firstVehicle.make);
      expect(details.ceremonialAddons.isNotEmpty, true);
      expect(details.amenities.isNotEmpty, true);
    });

    test('3. Service Categories — Ceremonial categories synchronized with seed', () async {
      final catResult = await categoryRepo.getCategories();
      expect(catResult.isSuccess, true);
      final categories = catResult.dataOrNull!;
      expect(categories.length, greaterThanOrEqualTo(4));
      expect(categories.any((c) => c.id == 'SVC_BARAAT'), true);
      expect(categories.any((c) => c.id == 'SVC_VIDAI'), true);
    });

    test('4. Full Auth Cycle & Token Persistence', () async {
      // 4A. Request OTP for customer
      final otpResult = await authRepo.requestOtp(phoneNumber: '9810000008');
      expect(otpResult.isSuccess, true, reason: 'OTP request must succeed');
      final sessionId = otpResult.dataOrNull!;
      expect(sessionId.isNotEmpty, true);
      expect(authRepo.lastDebugOtpCode, isNotNull, reason: 'Debug code must be returned in dev');

      // 4B. Verify OTP with authoritative code
      final verifyResult = await authRepo.verifyOtp(
        otpSessionId: sessionId,
        otpCode: authRepo.lastDebugOtpCode!,
      );
      expect(verifyResult.isSuccess, true, reason: 'OTP verify must succeed');
      final session = verifyResult.dataOrNull!;
      expect(session.userId.isNotEmpty, true);
      expect(session.role, UserRole.customer);
      // 4C. Check that access token was persisted to secure storage
      final storedToken = await storage.read(AppConstants.keyAccessToken);
      expect(storedToken, isNotNull);
      expect(storedToken!.startsWith('ey'), true, reason: 'Must be a JWT bearer token');
    });

    test('5. End-to-End Booking Submission with Idempotency & Replay', () async {
      // Reuses the authenticated session from Step 4 (stored in SecureStorage)

      final uniqueKey = 'live-test-key-${DateTime.now().millisecondsSinceEpoch}';
      final request = BookingSubmissionRequest(
        draftId: 'draft-test-1',
        vehicleId: 'VT_BMW5',
        vehicleName: 'BMW 5 Series',
        vehicleClass: 'LUXURY_SEDAN',
        chauffeurId: 'de88a65c-3da5-4cae-9636-328891664f07',
        ceremonyType: 'Baraat Procession',
        ceremonialAttire: 'Safa & Sherwani',
        specialInstructions: 'Royal entrance with music',
        serviceStartDateTime: DateTime.now().add(const Duration(days: 30)),
        serviceEndDateTime: DateTime.now().add(const Duration(days: 30, hours: 8)),
        routeDistanceKm: 42.0,
        city: 'Delhi NCR',
        pickupAddress: 'Sector 15, Gurugram',
        destinationAddress: 'The Leela Palace, Chanakyapuri, New Delhi',
        venueName: 'The Leela Palace',
        primaryContactName: 'Aarav Sharma',
        primaryContactPhone: '+919810000001',
        passengerCount: 4,
        basePricePaise: 3500000,
        estimatedTotalPaise: 3955000,
        advanceTokenPaise: 988750,
        idempotencyKey: uniqueKey,
      );

      // Submit booking
      final submitResult = await bookingRepo.submitBooking(request);
      expect(submitResult.isSuccess, true, reason: 'Booking submission must succeed on live server');
      final result = submitResult.dataOrNull!;
      expect(result.bookingId.isNotEmpty, true);
      expect(result.bookingReference.startsWith('SD-2026-'), true);
      expect(result.status, BookingStatus.requested);
      expect(result.estimatedTotalPaise, greaterThan(0));
      expect(result.advanceTokenPaise, greaterThan(0));
      expect(result.isIdempotentReplay, false);

      // Submit identical request (Idempotent Replay test)
      final replayResult = await bookingRepo.submitBooking(request);
      expect(replayResult.isSuccess, true);
      final replay = replayResult.dataOrNull!;
      expect(replay.bookingId, result.bookingId);
      expect(replay.bookingReference, result.bookingReference);
      expect(replay.isIdempotentReplay, true, reason: 'Same key within 24h must return idempotent replay');

      // Fetch user bookings
      final myBookingsResult = await bookingRepo.getMyBookings();
      expect(myBookingsResult.isSuccess, true);
      final myBookings = myBookingsResult.dataOrNull!;
      expect(myBookings.any((b) => b.id == result.bookingId), true);
    });
  });
}
