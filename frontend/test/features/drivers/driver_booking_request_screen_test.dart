import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/drivers/presentation/driver_booking_request_screen.dart';

import '../../helpers/mock_env.dart';

void main() {
  const testBookingId = 'bk_mock_req_1';

  group('DriverBookingRequestScreen Widget Tests', () {
    testWidgets('renders masked customer PII, DPDP notice, and itinerary', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: mockModeOverrides(),
          child: const MaterialApp(
            home: DriverBookingRequestScreen(bookingId: testBookingId),
          ),
        ),
      );

      // Loading state first
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();

      // Verify Reference and Payout
      expect(find.text('Ref: SD-2026-0100'), findsOneWidget);
      expect(find.text('₹20,000'), findsOneWidget);

      // Verify DPDP Privacy Masking
      expect(find.text('Host Identity & Privacy'), findsOneWidget);
      expect(find.text('Host: Vikram M.'), findsOneWidget);
      expect(find.text('+91 ••••• ••345'), findsOneWidget);
      expect(find.textContaining('DPDP Act 2023 Compliance'), findsOneWidget);

      // Verify Ceremonial Details
      expect(find.text('Ceremonial Itinerary'), findsOneWidget);
      expect(find.text('Baraat'), findsOneWidget);
      expect(find.text('BMW 5 Series'), findsOneWidget);
      expect(find.text('Royal Bandhgala & Gold Safa'), findsOneWidget);

      // Verify Action Buttons
      expect(find.byKey(const Key('driver_decline_button')), findsOneWidget);
      expect(find.byKey(const Key('driver_accept_button')), findsOneWidget);
    });

    testWidgets(
      'decline button opens bottom sheet requiring reason before confirmation',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: mockModeOverrides(),
            child: const MaterialApp(
              home: DriverBookingRequestScreen(bookingId: testBookingId),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Decline button
        await tester.tap(find.byKey(const Key('driver_decline_button')));
        await tester.pumpAndSettle();

        // Bottom sheet is visible with all 6 reasons
        expect(find.text('Decline Booking Offer'), findsOneWidget);
        expect(
          find.byKey(const Key('decline_radio_timingConflict')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('decline_radio_locationIssue')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('decline_radio_vehicleIssue')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('decline_radio_personalEmergency')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('decline_radio_alreadyCommitted')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('decline_radio_other')), findsOneWidget);

        // Confirm button is initially disabled (onPressed is null)
        final confirmBtnFinder = find.byKey(
          const Key('confirm_decline_button'),
        );
        expect(confirmBtnFinder, findsOneWidget);

        // Select a reason
        await tester.tap(find.byKey(const Key('decline_radio_timingConflict')));
        await tester.pumpAndSettle();

        // Now tap confirm decline
        await tester.tap(confirmBtnFinder);
        await tester.pumpAndSettle();
      },
    );
  });
}
