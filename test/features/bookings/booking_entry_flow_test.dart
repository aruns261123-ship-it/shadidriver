import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

void main() {
  Widget createWidgetToTest({required String initialLocation}) {
    final router = createShadiRouter(initialLocation: initialLocation);
    final mockBookingRepo = MockBookingRepository();
    final mockVehicleRepo = MockVehicleRepository();
    final mockDriverRepo = MockDriverRepository();

    return ProviderScope(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
        vehicleRepositoryProvider.overrideWithValue(mockVehicleRepo),
        driverRepositoryProvider.overrideWithValue(mockDriverRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('Milestone 4A — Booking Entry & Event Details Flow Tests', () {
    testWidgets(
      'BookingEntryScreen loads vehicle specs and initializes at Step 0',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerBookingCreatePath('v1'),
          ),
        );

        await tester.pumpAndSettle();

        // Check header and vehicle info
        expect(find.text('Booking Experience'), findsOneWidget);
        expect(find.textContaining('Vehicle ID: v1'), findsOneWidget);
        expect(find.text('BMW 5 Series'), findsOneWidget);

        // Check Step indicator
        expect(find.text('Ceremony'), findsOneWidget);
        expect(find.text('Date/Time'), findsOneWidget);
        expect(find.text('Route'), findsOneWidget);
        expect(find.text('Host'), findsOneWidget);

        // Verify Step 0 is active
        expect(find.text('1. Event & Ceremony Details'), findsOneWidget);
        expect(find.text('Baraat'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
      },
    );

    testWidgets(
      'End-to-end guided booking draft creation: Ceremony -> Date/Time -> Route -> Host -> Draft Summary',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerBookingCreatePath('v1'),
          ),
        );

        await tester.pumpAndSettle();

        // -----------------------------------------------------------
        // Step 0: Event & Ceremony Details
        // -----------------------------------------------------------
        expect(find.text('1. Event & Ceremony Details'), findsOneWidget);

        // Select 'Vidai'
        await tester.tap(find.text('Vidai'));
        await tester.pumpAndSettle();

        // Tap Continue
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // -----------------------------------------------------------
        // Step 1: Date & Time Selection
        // -----------------------------------------------------------
        expect(find.text('2. Date & Time Selection'), findsOneWidget);
        expect(find.text('Ceremony Date'), findsOneWidget);
        expect(find.text('Chauffeur Arrival Time'), findsOneWidget);

        // Select '12 Hours\n(Full Day)'
        await tester.ensureVisible(find.text('12 Hours\n(Full Day)'));
        await tester.tap(find.text('12 Hours\n(Full Day)'));
        await tester.pumpAndSettle();

        // Tap Continue
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // -----------------------------------------------------------
        // Step 2: Pickup & Destination
        // -----------------------------------------------------------
        expect(find.text('3. Pickup & Destination'), findsOneWidget);

        // Enter pickup address
        final pickupField = find.widgetWithText(
          TextField,
          'e.g., The Oberoi, Dr Zakir Hussain Marg',
        );
        expect(pickupField, findsOneWidget);
        await tester.enterText(pickupField, 'The Oberoi Hotel, New Delhi');
        await tester.pumpAndSettle();

        // Enter destination address
        final destField = find.widgetWithText(
          TextField,
          'e.g., Grand Imperial Banquets, MG Road',
        );
        expect(destField, findsOneWidget);
        await tester.enterText(destField, 'Grand Imperial Banquets, MG Road');
        await tester.pumpAndSettle();

        // Enter venue name
        final venueField = find.widgetWithText(
          TextField,
          'e.g., Grand Imperial Ballroom',
        );
        expect(venueField, findsOneWidget);
        await tester.enterText(venueField, 'The Royal Palm Pavilion');
        await tester.pumpAndSettle();

        // Tap Continue
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // -----------------------------------------------------------
        // Step 3: Passenger & Host Details
        // -----------------------------------------------------------
        expect(find.text('4. Passenger & Host Details'), findsOneWidget);

        // Enter host name
        final nameField = find.widgetWithText(TextField, 'e.g., Rajesh Sharma');
        expect(nameField, findsOneWidget);
        await tester.enterText(nameField, 'Aditya Singhal');
        await tester.pumpAndSettle();

        // Enter host mobile
        final phoneField = find.widgetWithText(TextField, 'e.g., 9876543210');
        expect(phoneField, findsOneWidget);
        await tester.enterText(phoneField, '9876543210');
        await tester.pumpAndSettle();

        // Tap 'Save & Continue'
        final saveButton = find.text('Save & Continue');
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // -----------------------------------------------------------
        // Milestone 4A Draft Saved Summary Card
        // -----------------------------------------------------------
        expect(find.text('Draft Created'), findsOneWidget);
        expect(find.text('Vidai'), findsOneWidget);
        expect(find.textContaining('Aditya Singhal'), findsOneWidget);
        expect(find.textContaining('9876543210'), findsOneWidget);
        expect(find.text('Return to Home'), findsOneWidget);
      },
    );

    testWidgets('Step navigation allows going back via Back button', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetToTest(
          initialLocation: RoutePaths.customerBookingCreatePath('v1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1. Event & Ceremony Details'), findsOneWidget);

      // Advance to Step 1
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('2. Date & Time Selection'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);

      // Tap Back
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('1. Event & Ceremony Details'), findsOneWidget);
    });

    testWidgets(
      'BookingEntryScreen displays error state for invalid vehicle ID',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerBookingCreatePath(
              'invalid_v999',
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Unable to initialize booking draft. Vehicle not found.'),
          findsOneWidget,
        );
      },
    );
  });
}
