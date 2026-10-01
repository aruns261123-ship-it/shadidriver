import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/drivers/presentation/driver_dashboard_screen.dart';

import '../../helpers/mock_env.dart';

void main() {
  group('DriverDashboardScreen Widget Tests', () {
    testWidgets(
      'renders the reference Fleet Home header, duty chips, and initial offers',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: mockModeOverrides(),
            child: const MaterialApp(home: DriverDashboardScreen()),
          ),
        );

        // Reference Fleet Home header first.
        expect(find.textContaining('Good morning,'), findsOneWidget);
        expect(find.textContaining('Your fleet is'), findsOneWidget);
        expect(find.text('cars in your fleet'), findsOneWidget);
        expect(find.text('Manage My Cars'), findsOneWidget);

        // Reference metric pair (AVAILABILITY / VERIFICATION) with the exact
        // status language.
        expect(find.text('AVAILABILITY'), findsOneWidget);
        expect(find.text('VERIFICATION'), findsOneWidget);

        // Live sections are below the fold in a lazily-built ListView —
        // scroll to the duty console.
        await tester.scrollUntilVisible(
          find.text('Operational Duty Status'),
          400,
          scrollable: find.byType(Scrollable).first,
        );

        // Verify duty chips (wire values unchanged).
        expect(find.byKey(const Key('duty_chip_AVAILABLE')), findsOneWidget);
        expect(
          find.byKey(const Key('duty_chip_AVAILABLE_NOW')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('duty_chip_BUSY')), findsOneWidget);
        expect(find.byKey(const Key('duty_chip_OFFLINE')), findsOneWidget);

        // Verify incoming offer card. scrollUntilVisible aligns its target
        // with the viewport edge, so scroll to each neighbour explicitly.
        await tester.scrollUntilVisible(
          find.text('Assigned Duties'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Assigned Duties'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('SD-2026-0100'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('SD-2026-0100'), findsOneWidget);
        expect(find.text('Baraat'), findsOneWidget);
        expect(find.text('BMW 5 Series'), findsOneWidget);
        expect(find.text('View Duty'), findsOneWidget);
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

        // Scroll to the duty console and switch OFFLINE. ensureVisible
        // brings the chip fully into the viewport so the tap lands.
        await tester.scrollUntilVisible(
          find.byKey(const Key('duty_chip_OFFLINE')),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.byKey(const Key('duty_chip_OFFLINE')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('duty_chip_OFFLINE')));
        await tester.pumpAndSettle();

        // Verify paused state — drag the (single) scrollable down until the
        // paused card is built and visible.
        var pausedVisible = false;
        for (var i = 0; i < 8 && !pausedVisible; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -350));
          await tester.pump(const Duration(milliseconds: 300));
          pausedVisible = find.text('Duty List Paused').evaluate().isNotEmpty;
        }
        expect(pausedVisible, isTrue);
        expect(find.text('SD-2026-0100'), findsNothing);

        // Tap Available chip to resume dispatch: drag back UP until the
        // chips are visible again.
        var chipsVisible = false;
        for (var i = 0; i < 10 && !chipsVisible; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, 350));
          await tester.pump(const Duration(milliseconds: 300));
          chipsVisible =
              find.byKey(const Key('duty_chip_AVAILABLE')).evaluate().isNotEmpty;
        }
        expect(chipsVisible, isTrue);
        await tester.ensureVisible(
          find.byKey(const Key('duty_chip_AVAILABLE')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('duty_chip_AVAILABLE')));
        await tester.pumpAndSettle();

        // Offers restored.
        var offersRestored = false;
        for (var i = 0; i < 8 && !offersRestored; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -350));
          await tester.pump(const Duration(milliseconds: 300));
          offersRestored = find.text('SD-2026-0100').evaluate().isNotEmpty;
        }
        expect(offersRestored, isTrue);
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

      // Tap Biometric lock icon in the header row.
      final biometricAction = find.byKey(
        const Key('driver_dashboard_biometric_lock_action'),
      );
      expect(biometricAction, findsOneWidget);
      await tester.tap(biometricAction);
      await tester.pumpAndSettle();

      // Verify modal sheet appears.
      expect(find.text('Chauffeur Duty Security'), findsOneWidget);
      expect(
        find.text(
          'Touch sensor or scan Face ID to verify identity and resume duty console.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.fingerprint_rounded), findsWidgets);

      // Tap biometric sensor to authenticate.
      await tester.tap(find.byIcon(Icons.fingerprint_rounded).last);
      await tester.pumpAndSettle();

      // Sheet dismissed and snackbar shown.
      expect(
        find.text('✓ Identity Verified • Duty Console Active'),
        findsOneWidget,
      );
    });
  });
}
