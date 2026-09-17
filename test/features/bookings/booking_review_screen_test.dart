import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';

void main() {
  group('BookingReviewScreen Widget Tests', () {
    late MockBookingRepository mockBookingRepo;
    late BookingDraft testDraft;

    setUp(() async {
      mockBookingRepo = MockBookingRepository();
      testDraft = BookingDraft.initial(
        vehicleId: 'v1',
        vehicleName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        chauffeurId: 'd1',
        basePricePaise: 2500000,
        estimatedTotalPaise: 2500000,
        advanceTokenPaise: 500000,
        advanceTokenLabel: 'Advance Token',
      ).copyWith(
        ceremonyType: 'Baraat',
        ceremonialAttire: 'Royal Bandhgala & Gold Safa',
        specialInstructions: 'Ceremonial slow drive',
        pickupAddress: 'The Oberoi Hotel, New Delhi',
        destinationAddress: 'Grand Imperial Banquets, MG Road',
        venueName: 'Imperial Ballroom',
        landmark: 'Gate 2',
        primaryContactName: 'Vikram Malhotra',
        primaryContactPhone: '9810012345',
        alternateContactPhone: '9811122233',
        passengerCount: 2,
      );

      await mockBookingRepo.createBookingDraft(testDraft);
    });

    Widget createWidgetToTest() {
      final router = createShadiRouter(
        initialLocation: RoutePaths.customerBookingReviewPath(testDraft.id),
      );

      return ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('renders all ceremonial review sections and values', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetToTest());
      await tester.pumpAndSettle();

      // Screen title and instruction banner
      expect(find.text('Review Reservation'), findsOneWidget);
      expect(
        find.textContaining('Please review your ceremonial itinerary'),
        findsOneWidget,
      );

      // Vehicle & Chauffeur
      expect(find.text('BMW 5 Series'), findsOneWidget);
      expect(find.textContaining('Luxury Sedan'), findsOneWidget);
      expect(find.textContaining('Assigned Chauffeur:'), findsOneWidget);

      // Ceremony & Attire
      expect(find.text('Ceremony & Attire'), findsOneWidget);
      expect(find.text('Baraat'), findsOneWidget);
      expect(find.text('Royal Bandhgala & Gold Safa'), findsOneWidget);
      expect(find.text('Ceremonial slow drive'), findsOneWidget);

      // Schedule & Timing
      expect(find.text('Schedule & Timing'), findsOneWidget);
      expect(find.textContaining('8 hrs'), findsNWidgets(2));

      // Route & Venue
      expect(find.text('The Oberoi Hotel, New Delhi'), findsOneWidget);
      expect(find.text('Grand Imperial Banquets, MG Road'), findsOneWidget);
      expect(find.text('Imperial Ballroom'), findsOneWidget);

      // Host & Guest Details
      expect(find.text('Vikram Malhotra'), findsOneWidget);
      expect(find.text('9810012345'), findsOneWidget);
      expect(find.text('9811122233'), findsOneWidget);
      expect(find.text('2 Passengers'), findsOneWidget);

      // Fare summary
      expect(find.text('Fare Summary'), findsOneWidget);
      expect(find.text('₹25,000'), findsOneWidget);
      expect(find.text('₹5,000'), findsOneWidget);
      expect(find.text('Advance Token'), findsOneWidget);

      // Action buttons
      expect(find.text('Edit Draft'), findsOneWidget);
      expect(find.text('Submit Booking Request'), findsOneWidget);
    });

    testWidgets(
      'tapping Submit Booking Request triggers submission and transitions to Result Screen',
      (tester) async {
        await tester.pumpWidget(createWidgetToTest());
        await tester.pumpAndSettle();

        final submitButton = find.text('Submit Booking Request');
        expect(submitButton, findsOneWidget);

        await tester.tap(submitButton);
        await tester.pump(); // Start async submit

        // Verify button indicates progress
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Await completion and transition
        await tester.pumpAndSettle();

        // Must transition to Result screen with non-confirmed wording
        expect(find.text('Request Submitted'), findsOneWidget);
        expect(
          find.text('Booking Request Received • Awaiting Confirmation'),
          findsOneWidget,
        );
        expect(find.textContaining('SD-2026-'), findsOneWidget);
      },
    );
  });
}
