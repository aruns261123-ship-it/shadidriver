import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';
import 'package:shadidriver/features/search/domain/entities/search_query.dart';
import 'package:shadidriver/features/search/domain/entities/search_sort.dart';
import 'package:shadidriver/features/vehicles/domain/entities/pricing_summary.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_details.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';
import 'package:shadidriver/features/vehicles/domain/repositories/vehicle_repository.dart';

/// Real backend primary keys are UUIDs. The placeholder ids used by the mock
/// fixtures ('v1') hide every width problem caused by a 36-character id, which
/// is exactly what the running app renders.
const kVehicleUuid = '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e';
const kChauffeurUuid = 'de88a65c-3da5-4cae-9636-328891664f07';

VehicleDetails uuidVehicle() => const VehicleDetails(
  id: kVehicleUuid,
  make: 'Mercedes-Benz',
  model: 'S-Class 580 4MATIC Launch Edition',
  year: 2024,
  vehicleClass: 'Ultra Luxury',
  seatingCapacity: 4,
  transmission: 'AUTOMATIC',
  verificationStatus: 'VERIFIED',
  galleryUrls: [],
  suitabilityInfo: 'Executive ceremonial mobility benchmark.',
  suitableCeremonies: ['Bridal Entry', 'Reception'],
  amenities: ['Dual-Zone Rear AC'],
  ceremonialAddons: [],
  pricing: PricingSummary(basePriceCents: 12500000, billingUnit: 'DAY'),
  rating: 4.9,
  reviewCount: 1284,
  isAvailableNow: true,
);

class UuidVehicleRepository implements VehicleRepository {
  final VehicleDetails details;
  UuidVehicleRepository(this.details);

  @override
  Future<Result<VehicleDetails>> getVehicleDetails(String vehicleId) async =>
      vehicleId == details.id
      ? Result.success(details)
      : Result.failure(NotFoundFailure('not found'));

  @override
  Future<Result<VehicleSummary>> getVehicleById(String vehicleId) async =>
      Result.failure(NotFoundFailure('not found'));

  @override
  Future<Result<List<VehicleSummary>>> getAvailableVehicles({
    String? categoryId,
    DateTime? eventStartTime,
    DateTime? eventEndTime,
  }) async => Result.success(const []);

  @override
  Future<Result<List<VehicleSummary>>> getFeaturedVehicles() async =>
      Result.success(const []);

  @override
  Future<Result<List<VehicleSummary>>> searchVehicles({
    required VehicleSearchQuery query,
    required SearchSort sort,
  }) async => Result.success(const []);
}

BookingDraft uuidDraft() => BookingDraft.initial(
  vehicleId: kVehicleUuid,
  vehicleName: 'Mercedes-Benz S-Class 580 4MATIC Launch Edition',
  vehicleClass: 'Ultra Luxury',
  basePricePaise: 12500000,
  estimatedTotalPaise: 12500000,
  advanceTokenPaise: 2500000,
).copyWith(
  pickupAddress: 'The Leela Palace, Chanakyapuri, New Delhi',
  destinationAddress: 'ITC Grand Bharat, Gurugram',
  primaryContactName: 'Aarav Sharma',
  primaryContactPhone: '9810000001',
);

/// Bounded settle: several screens keep a progress animation running, so
/// `pumpAndSettle` would never return. Pump a fixed number of frames — enough
/// for the initial futures, layout and paint (where overflow is reported).
Future<List<FlutterErrorDetails>> pumpScreen(
  WidgetTester tester,
  Widget app, {
  required double width,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);

  final captured = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = captured.add;
  await tester.pumpWidget(app);
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  FlutterError.onError = previous;
  tester.takeException();
  return captured;
}

void expectNoOverflow(
  List<FlutterErrorDetails> errors, {
  required double width,
  required String screen,
}) {
  for (final error in errors) {
    debugPrint(error.toString());
  }
  expect(
    errors,
    isEmpty,
    reason: '$screen must not overflow at ${width}dp (diagnostics above)',
  );
}

void main() {
  group('Real-data layout — UUID ids on a narrow phone', () {
    testWidgets(
      'BookingEntryScreen header fits at 320dp',
      timeout: const Timeout(Duration(seconds: 90)),
      (tester) async {
        final router = createShadiRouter(
          initialLocation: RoutePaths.customerBookingCreatePath(kVehicleUuid),
        );
        final errors = await pumpScreen(
          tester,
          ProviderScope(
            overrides: [
              vehicleRepositoryProvider.overrideWithValue(
                UuidVehicleRepository(uuidVehicle()),
              ),
              bookingRepositoryProvider.overrideWithValue(
                MockBookingRepository(),
              ),
              driverRepositoryProvider.overrideWithValue(MockDriverRepository()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
          width: 320,
        );

        expectNoOverflow(errors, width: 320, screen: 'BookingEntryScreen');
      },
    );

    testWidgets(
      'BookingReviewScreen fits at 320dp',
      timeout: const Timeout(Duration(seconds: 90)),
      (tester) async {
        final repo = MockBookingRepository();
        final draft = uuidDraft();
        // MockBookingRepository uses a real delay; seed it on the real clock
        // (inside testWidgets the fake clock never advances on its own).
        await tester.runAsync(() => repo.createBookingDraft(draft));

        final router = createShadiRouter(
          initialLocation: RoutePaths.customerBookingReviewPath(draft.id),
        );
        final errors = await pumpScreen(
          tester,
          ProviderScope(
            overrides: [bookingRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp.router(routerConfig: router),
          ),
          width: 320,
        );

        expectNoOverflow(errors, width: 320, screen: 'BookingReviewScreen');
        // The shortened reference keeps the real value reachable.
        expect(find.textContaining('Vehicle ID:'), findsOneWidget);
      },
    );

    testWidgets(
      'VehicleDetailsScreen fits at 320dp',
      timeout: const Timeout(Duration(seconds: 90)),
      (tester) async {
        final router = createShadiRouter(
          initialLocation: RoutePaths.customerVehicleDetailsPath(kVehicleUuid),
        );
        final errors = await pumpScreen(
          tester,
          ProviderScope(
            overrides: [
              vehicleRepositoryProvider.overrideWithValue(
                UuidVehicleRepository(uuidVehicle()),
              ),
              driverRepositoryProvider.overrideWithValue(MockDriverRepository()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
          width: 320,
        );

        expectNoOverflow(errors, width: 320, screen: 'VehicleDetailsScreen');
      },
    );
  });
}
