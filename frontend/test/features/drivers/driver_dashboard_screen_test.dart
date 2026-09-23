import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/drivers/presentation/driver_dashboard_screen.dart';

import '../../helpers/mock_env.dart';

void main() {
  group('DriverDashboardScreen Widget Tests', () {
    testWidgets(
      'renders Chauffeur Console, duty status chips, and initial offers',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: mockModeOverrides(),
            child: const MaterialApp(home: DriverDashboardScreen()),
          ),
        );

        // Loading indicator first
        expect(find.byType(CircularProgressIndicator), findsWidgets);

        await tester.pumpAndSettle();

        // Verify header
        expect(find.text('Chauffeur Console'), findsOneWidget);
        expect(find.text('Operational Duty Status'), findsOneWidget);

        // Verify duty chips
        expect(find.byKey(const Key('duty_chip_AVAILABLE')), findsOneWidget);
        expect(
          find.byKey(const Key('duty_chip_AVAILABLE_NOW')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('duty_chip_BUSY')), findsOneWidget);
        expect(find.byKey(const Key('duty_chip_OFFLINE')), findsOneWidget);

        // Verify incoming offer card
        expect(find.text('Incoming Booking Offers'), findsOneWidget);
        expect(find.text('SD-2026-0100'), findsOneWidget);
        expect(find.text('Baraat'), findsOneWidget);
        expect(find.text('BMW 5 Series'), findsOneWidget);
        expect(find.text('Review Offer'), findsOneWidget);
      },
    );

    testWidgets(
      'switching duty status to OFFLINE pauses dispatch and hides offers',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: mockModeOverrides(),
            child: const MaterialApp(home: DriverDashboardScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Initial state has offers
        expect(find.text('SD-2026-0100'), findsOneWidget);

        // Tap Offline chip
        await tester.tap(find.byKey(const Key('duty_chip_OFFLINE')));
        await tester.pumpAndSettle();

        // Verify paused state
        expect(find.text('Dispatch Offers Paused'), findsOneWidget);
        expect(find.text('SD-2026-0100'), findsNothing);

        // Tap Available chip to resume dispatch
        await tester.tap(find.byKey(const Key('duty_chip_AVAILABLE')));
        await tester.pumpAndSettle();

        // Offers restored
        expect(find.text('SD-2026-0100'), findsOneWidget);
      },
    );

    testWidgets('tapping biometric lock action opens duty security sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: mockModeOverrides(),
          child: const MaterialApp(home: DriverDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Biometric lock icon in app bar
      final biometricAction = find.byKey(
        const Key('driver_dashboard_biometric_lock_action'),
      );
      expect(biometricAction, findsOneWidget);
      await tester.tap(biometricAction);
      await tester.pumpAndSettle();

      // Verify modal sheet appears
      expect(find.text('Chauffeur Duty Security'), findsOneWidget);
      expect(
        find.text(
          'Touch sensor or scan Face ID to verify identity and resume duty console.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.fingerprint_rounded), findsWidgets);

      // Tap biometric sensor to authenticate
      await tester.tap(find.byIcon(Icons.fingerprint_rounded).last);
      await tester.pumpAndSettle();

      // Sheet dismissed and snackbar shown
      expect(
        find.text('✓ Identity Verified • Duty Console Active'),
        findsOneWidget,
      );
    });
  });
}
