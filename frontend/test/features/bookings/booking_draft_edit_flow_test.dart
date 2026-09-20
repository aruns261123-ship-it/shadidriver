import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

void main() {
  group('Booking Draft Edit Flow Widget & Navigation Tests', () {
    late MockBookingRepository mockBookingRepo;
    late MockVehicleRepository mockVehicleRepo;
    late MockDriverRepository mockDriverRepo;
    late BookingDraft seededDraft;

    setUp(() async {
      mockBookingRepo = MockBookingRepository();
      mockVehicleRepo = MockVehicleRepository();
      mockDriverRepo = MockDriverRepository();

      seededDraft =
          BookingDraft.initial(
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

      await mockBookingRepo.createBookingDraft(seededDraft);
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
      'Review Reservation Edit Draft button opens Booking Entry Wizard with existing values',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerBookingReviewPath(
              seededDraft.id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Review Reservation screen renders
        expect(find.text('Review Reservation'), findsOneWidget);
        expect(find.text('Vikram Malhotra'), findsOneWidget);

        // 2. Tap 'Edit Draft'
        final editButton = find.text('Edit Draft');
        expect(editButton, findsOneWidget);
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        // 3. Confirm wizard opened (Step 0: Ceremony & Attire)
        expect(find.text('Edit Reservation'), findsOneWidget);
        expect(find.text('1. Event & Ceremony Details'), findsOneWidget);
        expect(find.text('Baraat'), findsOneWidget);
        expect(find.text('Royal Bandhgala & Gold Safa'), findsOneWidget);

        // Advance to Step 1 (Date/Time)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('2. Service Timing & Duration'), findsOneWidget);

        // Advance to Step 2 (Route & Venue)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('3. Pickup & Destination'), findsOneWidget);
        expect(find.text('The Oberoi Hotel, New Delhi'), findsOneWidget);
        expect(find.text('Grand Imperial Banquets, MG Road'), findsOneWidget);

        // Advance to Step 3 (Passenger & Host)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('4. Passenger & Host Details'), findsOneWidget);
        expect(find.text('Vikram Malhotra'), findsOneWidget);
        expect(find.text('9810012345'), findsOneWidget);

        // Verify button text is 'Save Changes' in edit mode
        expect(find.text('Save Changes'), findsOneWidget);
      },
    );

    testWidgets(
      'Editing fields, saving changes retains same draft ID and updates Review screen',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerBookingReviewPath(
              seededDraft.id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Edit Draft
        await tester.tap(find.text('Edit Draft'));
        await tester.pumpAndSettle();

        // Select 'Vidai' ceremony in Step 0
        await tester.tap(find.text('Vidai'));
        await tester.pumpAndSettle();

        // Navigate to Step 3 (Passenger & Host)
        await tester.tap(find.text('Continue')); // to Step 1
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue')); // to Step 2
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue')); // to Step 3
        await tester.pumpAndSettle();

        // Edit host name
        final nameField = find.widgetWithText(TextField, 'Vikram Malhotra');
        expect(nameField, findsOneWidget);
        await tester.enterText(nameField, 'Amitabh Bachchan');
        await tester.pumpAndSettle();

        // Tap 'Save Changes'
        await tester.tap(find.text('Save Changes'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Verify snackbar appears
        expect(find.text('Booking draft updated'), findsOneWidget);

        // Advance past SnackBar animation and timer
        await tester.pump(const Duration(seconds: 3));

        // Verify returned to Review Reservation with updated values
        expect(find.text('Review Reservation'), findsOneWidget);
        expect(find.text('Vidai'), findsOneWidget);
        expect(find.text('Amitabh Bachchan'), findsOneWidget);

        // Verify original draft ID is preserved in repository
        final future = mockBookingRepo.getBookingDraft(seededDraft.id);
        await tester.pump(const Duration(milliseconds: 200));
        final draftInRepo = await future;
        expect(draftInRepo.dataOrNull?.id, equals(seededDraft.id));
        expect(
          draftInRepo.dataOrNull?.primaryContactName,
          equals('Amitabh Bachchan'),
        );
        expect(draftInRepo.dataOrNull?.ceremonyType, equals('Vidai'));
      },
    );

    testWidgets(
      'Unsaved changes confirmation dialog: Discard vs Keep Editing',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerBookingCreatePath(
              'v1',
              draftId: seededDraft.id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Change ceremony type to create unsaved dirty state
        await tester.tap(find.text('Vidai'));
        await tester.pumpAndSettle();

        // Tap AppBar back button
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        // Verify confirmation dialog is shown
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
        expect(find.text('Keep Editing'), findsOneWidget);
        expect(find.text('Discard Changes'), findsOneWidget);

        // Tap Keep Editing -> stays on screen
        await tester.tap(find.text('Keep Editing'));
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsNothing);
        expect(find.text('1. Event & Ceremony Details'), findsOneWidget);

        // Tap Back again and Discard Changes
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard Changes'));
        await tester.pumpAndSettle();

        // Screen popped
        expect(find.text('Discard unsaved changes?'), findsNothing);
      },
    );
  });
}
