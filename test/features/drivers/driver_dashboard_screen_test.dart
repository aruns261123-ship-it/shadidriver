import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/drivers/presentation/driver_dashboard_screen.dart';

void main() {
  group('DriverDashboardScreen Widget Tests', () {
    testWidgets(
      'renders Chauffeur Console, duty status chips, and initial offers',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: DriverDashboardScreen()),
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
          const ProviderScope(
            child: MaterialApp(home: DriverDashboardScreen()),
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
  });
}
