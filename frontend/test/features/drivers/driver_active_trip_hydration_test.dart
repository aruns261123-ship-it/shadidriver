import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_trip_stage.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_active_trip_controller.dart';

void main() {
  group('DriverActiveTripController store hydration', () {
    test(
      'console hydrates from the booking store instead of the mock seed',
      () async {
        final bookingRepo = MockBookingRepository();

        // Create + accept a REAL booking that is not the seeded demo trip.
        final draft = BookingDraft.initial(
          vehicleId: 'v1',
          vehicleName: 'Rolls-Royce Ghost',
          vehicleClass: 'Ultra-Luxury',
          chauffeurId: 'd1',
          basePricePaise: 2500000,
          estimatedTotalPaise: 2500000,
          advanceTokenPaise: 500000,
        ).copyWith(ceremonyType: 'Sangeet');

        final submitResult = await bookingRepo.submitBooking(
          BookingSubmissionRequest.fromDraft(
            draft,
            idempotencyKey: 'idem_hydration_test_1',
          ),
        );
        final booking = submitResult.fold(
          (l) => throw l,
          (r) => r,
        );
        expect(booking.bookingReference, isNot('SD-2026-0100'));
        await bookingRepo.acceptBooking(
          bookingId: booking.bookingId,
          driverId: 'd1',
        );

        final container = ProviderContainer(
          overrides: [bookingRepositoryProvider.overrideWithValue(bookingRepo)],
        );
        addTearDown(container.dispose);

        // Initial synchronous state is the seed fallback.
        final initial = container.read(
          driverActiveTripControllerProvider(booking.bookingId),
        );
        expect(initial.trip.bookingId, booking.bookingId);
        expect(initial.trip.bookingReference, 'SD-2026-0100');

        // Allow the async hydration to complete.
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final hydrated = container.read(
          driverActiveTripControllerProvider(booking.bookingId),
        );

        // The console now reflects the REAL store record, not the seed.
        expect(hydrated.trip.bookingReference, booking.bookingReference);
        expect(hydrated.trip.ceremonyType, 'Sangeet');
        expect(hydrated.trip.vehicleName, 'Rolls-Royce Ghost');
        expect(hydrated.trip.stage, DriverTripStage.assigned);
      },
    );

    test('unknown booking IDs keep the seed fallback (no crash)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(
        driverActiveTripControllerProvider('totally_unknown_id'),
      );
      expect(state.trip.bookingId, 'totally_unknown_id');
      expect(state.trip.bookingReference, 'SD-2026-0100');

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Store lookup failed — the seed fallback remains intact.
      final after = container.read(
        driverActiveTripControllerProvider('totally_unknown_id'),
      );
      expect(after.trip.bookingReference, 'SD-2026-0100');
      expect(after.trip.stage, DriverTripStage.assigned);
    });
  });
}
