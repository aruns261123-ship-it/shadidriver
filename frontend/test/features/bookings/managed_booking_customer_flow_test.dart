import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

/// The managed-booking model replaced the old marketplace flow:
///
///   Customer selects cars → submits a REQUEST → ShadiDriver operations
///   allocates vehicles and chauffeurs → contacts the customer → the customer
///   confirms.
///
/// There is NO customer→driver offer, no driver "accept", and the customer
/// never receives chauffeur identity. This test pins that on the customer's
/// own screens (the previous version of this file asserted the retired
/// behaviour: 'Driver Accepted' and 'Confirmed (ID: d1)' visible to the host).
void main() {
  late MockBookingRepository mockBookingRepo;
  late MockDriverRepository mockDriverRepo;
  late MockVehicleRepository mockVehicleRepo;

  setUp(() {
    mockBookingRepo = MockBookingRepository();
    mockDriverRepo = MockDriverRepository();
    mockVehicleRepo = MockVehicleRepository();
  });

  BookingSubmissionRequest hostRequest() {
    final draft =
        BookingDraft.initial(
          vehicleId: 'v1',
          vehicleName: 'Rolls-Royce Ghost',
          vehicleClass: 'Ultra-Luxury',
          chauffeurId: 'd1',
          basePricePaise: 2500000,
          estimatedTotalPaise: 2500000,
          advanceTokenPaise: 500000,
          advanceTokenLabel: '20% Advance Token Deposit',
        ).copyWith(
          ceremonyType: 'Baraat Procession',
          pickupAddress: 'The Imperial, Janpath, New Delhi',
          destinationAddress: 'Taj Palace, Chanakyapuri, New Delhi',
          primaryContactName: 'Aarav Sharma',
          primaryContactPhone: '+91 98765 43210',
        );

    return BookingSubmissionRequest.fromDraft(
      draft,
      idempotencyKey: 'idem_flow_test_1',
    );
  }

  testWidgets(
    'a submitted request is presented as a request, not a driver acceptance',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      // The mock repository completes on a short timer, so advance the clock
      // before awaiting the submission.
      final submitFuture = mockBookingRepo.submitBooking(hostRequest());
      await tester.pump(const Duration(milliseconds: 400));
      final bookingId = (await submitFuture).fold(
        (failure) => throw failure,
        (booking) => booking.bookingId,
      );

      final router = createShadiRouter(
        initialLocation: RoutePaths.customerBookingResultPath(bookingId),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
            driverRepositoryProvider.overrideWithValue(mockDriverRepo),
            vehicleRepositoryProvider.overrideWithValue(mockVehicleRepo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // The request the customer submitted reads as pending operations.
      expect(find.text(BookingStatus.requested.displayLabel), findsWidgets);

      // Nothing may imply a driver accepted, and no chauffeur identity may
      // reach the host's screen.
      expect(find.text('Driver Accepted'), findsNothing);
      expect(find.textContaining('Confirmed (ID:'), findsNothing);
      expect(find.textContaining('d1'), findsNothing);
    },
  );

  test('the customer-facing status copy never mentions a driver accepting', () {
    for (final status in BookingStatus.values) {
      final copy = '${status.displayLabel} ${status.customerSubtitle}';
      expect(copy.toLowerCase(), isNot(contains('driver accepted')));
      expect(copy.toLowerCase(), isNot(contains('awaiting chauffeur')));
    }
  });
}
