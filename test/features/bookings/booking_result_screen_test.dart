import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_result.dart';

void main() {
  group('BookingResultScreen Widget Tests', () {
    late MockBookingRepository mockRepo;
    late BookingSubmissionResult testSubmission;

    setUp(() async {
      mockRepo = MockBookingRepository();
      final draft =
          BookingDraft.initial(
            vehicleId: 'v1',
            vehicleName: 'BMW 5 Series',
            vehicleClass: 'Luxury Sedan',
            chauffeurId: 'd1',
            basePricePaise: 2500000,
            estimatedTotalPaise: 2500000,
            advanceTokenPaise: 500000,
          ).copyWith(
            pickupAddress: 'The Oberoi Hotel, New Delhi',
            destinationAddress: 'Grand Imperial Banquets, MG Road',
            primaryContactName: 'Vikram Malhotra',
            primaryContactPhone: '9810012345',
          );

      final req = BookingSubmissionRequest.fromDraft(
        draft,
        idempotencyKey: 'res_screen_test_key',
      );
      final res = await mockRepo.submitBooking(req);
      testSubmission = res.dataOrNull!;
    });

    Widget createWidgetToTest() {
      final router = createShadiRouter(
        initialLocation: RoutePaths.customerBookingResultPath(
          testSubmission.bookingId,
        ),
      );

      return ProviderScope(
        overrides: [bookingRepositoryProvider.overrideWithValue(mockRepo)],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets(
      'displays non-confirmed submission status and booking reference',
      (tester) async {
        await tester.pumpWidget(createWidgetToTest());
        await tester.pumpAndSettle();

        // 1. Must display server-authoritative submitted status
        expect(find.text('Request Submitted'), findsOneWidget);
        expect(
          find.text('Booking Request Received • Awaiting Confirmation'),
          findsOneWidget,
        );

        // 2. MUST NOT claim to be confirmed
        expect(find.text('Booking Confirmed'), findsNothing);
        expect(find.text('Confirmed Reservation'), findsNothing);

        // 3. Booking reference badge
        expect(
          find.textContaining(testSubmission.bookingReference),
          findsOneWidget,
        );

        // 4. Ceremonial itinerary recap
        expect(find.text('Ceremonial Itinerary'), findsOneWidget);
        expect(find.text('BMW 5 Series'), findsOneWidget);
        expect(find.text('Baraat'), findsOneWidget);
        expect(find.text('The Oberoi Hotel, New Delhi'), findsOneWidget);

        // 5. Pricing & Advance Token
        expect(find.text('Fare & Deposit Summary'), findsOneWidget);
        expect(find.text('₹25,000'), findsOneWidget);
        expect(find.text('₹5,000'), findsOneWidget);

        // 6. Action buttons
        expect(find.text('Return to Home'), findsOneWidget);
        expect(find.text('View My Bookings'), findsOneWidget);
      },
    );

    testWidgets(
      'Return to Home button navigates safely back to customer home',
      (tester) async {
        await tester.pumpWidget(createWidgetToTest());
        await tester.pumpAndSettle();

        final homeBtn = find.text('Return to Home');
        expect(homeBtn, findsOneWidget);

        await tester.tap(homeBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('Find the perfect ride for your celebration'),
          findsOneWidget,
        );
      },
    );
  });
}
