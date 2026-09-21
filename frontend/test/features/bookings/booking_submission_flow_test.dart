import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

void main() {
  group('Milestone 4B: End-to-End Customer Booking Flow Test', () {
    late MockBookingRepository mockBookingRepo;
    late MockVehicleRepository mockVehicleRepo;
    late MockDriverRepository mockDriverRepo;

    setUp(() {
      mockBookingRepo = MockBookingRepository();
      mockVehicleRepo = MockVehicleRepository();
      mockDriverRepo = MockDriverRepository();
    });

    Widget createWidgetToTest({required String initialLocation}) {
      final router = createShadiRouter(initialLocation: initialLocation);

      return ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
          vehicleRepositoryProvider.overrideWithValue(mockVehicleRepo),
          driverRepositoryProvider.overrideWithValue(mockDriverRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets(
      'Complete Journey: Vehicle Details -> Book Now -> Draft Wizard -> Review -> Submit -> Result -> Home',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerVehicleDetailsPath('v1'),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Vehicle Details: Tap 'Book Now'
        expect(find.text('BMW 5 Series'), findsWidgets);
        final bookNowBtn = find.text('Book Now');
        expect(bookNowBtn, findsOneWidget);
        await tester.tap(bookNowBtn);
        await tester.pumpAndSettle();

        // 2. Step 0 (Ceremony): Tap Continue
        expect(find.text('Booking Experience'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 3. Step 1 (Timing & Duration): Tap Continue
        expect(find.text('2. Service Timing & Duration'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 4. Step 2 (Route): Enter pickup and destination
        expect(find.text('3. Pickup & Destination'), findsOneWidget);
        final pickupField = find.widgetWithText(
          TextField,
          'e.g., The Oberoi, Dr Zakir Hussain Marg',
        );
        await tester.enterText(pickupField, 'The Oberoi Hotel, New Delhi');
        final destField = find.widgetWithText(
          TextField,
          'e.g., Grand Imperial Banquets, MG Road',
        );
        await tester.enterText(destField, 'Grand Imperial Banquets, MG Road');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 5. Step 3 (Host Details): Enter primary contact
        expect(find.text('4. Passenger & Host Details'), findsOneWidget);
        final nameField = find.widgetWithText(TextField, 'e.g., Rajesh Sharma');
        await tester.enterText(nameField, 'Vikram Malhotra');
        final phoneField = find.widgetWithText(TextField, 'e.g., 9876543210');
        await tester.enterText(phoneField, '9810012345');
        await tester.pumpAndSettle();

        // Tap 'Save & Continue' to save draft
        await tester.tap(find.text('Save & Continue'));
        await tester.pumpAndSettle();

        // Draft summary card is visible
        expect(find.text('Draft Created'), findsOneWidget);

        // Tap 'Review & Submit Booking'
        final reviewBtn = find.text('Review & Submit Booking');
        expect(reviewBtn, findsOneWidget);
        await tester.ensureVisible(reviewBtn);
        await tester.pumpAndSettle();
        await tester.tap(reviewBtn);
        await tester.pumpAndSettle();

        // 6. Review Screen: Verify all values and tap 'Submit Booking Request'
        expect(find.text('Review Reservation'), findsOneWidget);
        expect(find.text('BMW 5 Series'), findsOneWidget);
        expect(find.text('The Oberoi Hotel, New Delhi'), findsOneWidget);
        expect(find.text('Vikram Malhotra'), findsOneWidget);
        expect(find.text('₹25,000'), findsOneWidget);

        final submitRequestBtn = find.text('Submit Booking Request');
        expect(submitRequestBtn, findsOneWidget);
        await tester.tap(submitRequestBtn);
        await tester.pumpAndSettle();

        // 7. Result Screen: Server-authoritative status 'Request Submitted'
        expect(find.text('Request Submitted'), findsOneWidget);
        expect(
          find.text('Booking Request Received • Awaiting Confirmation'),
          findsOneWidget,
        );
        expect(find.textContaining('SD-2026-'), findsOneWidget);

        // 8. Return to Home
        final returnHomeBtn = find.text('Return to Home');
        expect(returnHomeBtn, findsOneWidget);
        await tester.tap(returnHomeBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('Find the perfect ride for your celebration'),
          findsOneWidget,
        );
      },
    );
  });
}
