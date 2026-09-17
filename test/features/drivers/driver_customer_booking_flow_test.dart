import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_dashboard_controller.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

void main() {
  late MockBookingRepository mockBookingRepo;
  late MockDriverRepository mockDriverRepo;
  late MockVehicleRepository mockVehicleRepo;

  setUp(() {
    mockBookingRepo = MockBookingRepository();
    mockDriverRepo = MockDriverRepository();
    mockVehicleRepo = MockVehicleRepository();
  });

  group('Milestone 5: Customer Submission -> Driver Accept Flow Integration',
      () {
    testWidgets(
      'Customer submits booking -> Driver accepts -> Customer view shows driverAccepted & assigned chauffeur',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());

        // 1. Customer Submits a Booking
        final draft = BookingDraft.initial(
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

        final submitReq = BookingSubmissionRequest.fromDraft(
          draft,
          idempotencyKey: 'idem_flow_test_1',
        );

        // Submit the booking intent into the repository
        final submitFuture = mockBookingRepo.submitBooking(submitReq);
        await tester.pump(const Duration(milliseconds: 300));
        final submitResult = await submitFuture;
        final booking = submitResult.fold((l) => throw l, (r) => r);
        expect(booking.status, BookingStatus.requested);
        final bookingId = booking.bookingId;

        // 2. Initialize App Shell at Driver Portal
        final router = createShadiRouter(initialLocation: RoutePaths.driver);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
              driverRepositoryProvider.overrideWithValue(mockDriverRepo),
              vehicleRepositoryProvider.overrideWithValue(mockVehicleRepo),
              currentDriverIdProvider.overrideWithValue('d1'),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // Verify incoming offer card is present on Driver Dashboard
        expect(find.text(booking.bookingReference), findsOneWidget);
        expect(find.text('Baraat Procession'), findsOneWidget);

        // 3. Driver navigates to Booking Request details
        router.go(RoutePaths.driverRequestDetailsPath(bookingId));
        await tester.pumpAndSettle();

        // Verify privacy masking: 'Aarav Sharma' -> 'Host: Aarav S.', phone masked
        expect(find.text('Host Identity & Privacy'), findsOneWidget);
        expect(find.text('Host: Aarav S.'), findsOneWidget);
        expect(find.text('+91 ••••• ••210'), findsOneWidget);
        expect(find.textContaining('DPDP Act 2023 Compliance'), findsOneWidget);

        // Driver taps Accept Offer
        final acceptBtn = find.byKey(const Key('driver_accept_button'));
        expect(acceptBtn, findsOneWidget);
        await tester.tap(acceptBtn);
        await tester.pumpAndSettle();

        // Verify driver repository state
        final detailFuture = mockBookingRepo.getDriverBookingDetails(
          bookingId: bookingId,
          driverId: 'd1',
        );
        await tester.pump(const Duration(milliseconds: 300));
        final detailResult = await detailFuture;
        expect(detailResult.isSuccess, isTrue);

        final customerFuture = mockBookingRepo.getSubmissionResult(bookingId);
        await tester.pump(const Duration(milliseconds: 300));
        final customerViewResult = await customerFuture;
        final customerResult = customerViewResult.fold(
          (l) => throw l,
          (r) => r,
        );
        expect(customerResult?.status, BookingStatus.driverAccepted);
        expect(customerResult?.chauffeurId, 'd1');

        // 4. Customer views their booking result screen
        router.go(RoutePaths.customerBookingResultPath(bookingId));
        await tester.pumpAndSettle();

        // Customer screen displays Driver Accepted and Confirmed Chauffeur
        expect(find.text('Driver Accepted'), findsOneWidget);
        expect(
          find.text('Chauffeur Confirmed • Ceremonial Chauffeur Assigned'),
          findsOneWidget,
        );
        expect(find.text('Confirmed (ID: d1)'), findsOneWidget);

        // 5. Concurrency Check: Second driver (d2) cannot accept
        final secondFuture = mockBookingRepo.acceptBooking(
          bookingId: bookingId,
          driverId: 'd2',
        );
        await tester.pump(const Duration(milliseconds: 300));
        final secondDriverAccept = await secondFuture;
        expect(secondDriverAccept.isFailure, isTrue);
        secondDriverAccept.fold(
          (failure) {
            expect(failure, isA<ConflictFailure>());
            expect(
              failure.message,
              contains('already been accepted by another chauffeur'),
            );
          },
          (r) =>
              fail('Should have rejected second driver with ConflictFailure'),
        );
      },
    );
  });
}
