import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/profile/presentation/admin_console_screen.dart';

import '../../helpers/mock_env.dart';

/// The reference Super Admin desktop console (PAGE 04): sidebar navigation,
/// operations header, KPI grid, and the Verification workspace.
void main() {
  Future<void> pumpConsole(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mockModeOverrides(),
        child: const MaterialApp(home: AdminConsoleScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('AdminConsoleScreen — reference desktop shell', () {
    testWidgets('renders the reference sidebar navigation', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpConsole(tester);

      // Reference sidebar nav (10 items).
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Drivers'), findsOneWidget);
      expect(find.text('Cars'), findsOneWidget);
      expect(find.text('Verification'), findsOneWidget);
      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('Pricing'), findsOneWidget);
      expect(find.text('Reviews'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Reference identity block.
      expect(find.text('Aditi Kapoor'), findsOneWidget);
      expect(find.text('Super Admin'), findsOneWidget);

      // Reference header.
      expect(find.text('OPERATIONS / DASHBOARD'), findsOneWidget);
      expect(find.text('Live operations'), findsOneWidget);
    });

    testWidgets('renders the KPI grid with the reference labels', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpConsole(tester);

      expect(find.text('Total customers'), findsOneWidget);
      expect(find.text('Active drivers'), findsOneWidget);
      expect(find.text('Available cars'), findsOneWidget);
      expect(find.text('Pending verification'), findsOneWidget);

      // Ops cards.
      expect(find.text('Booking operations'), findsOneWidget);
      expect(find.text('Verification queue'), findsOneWidget);
      expect(find.text('Recent bookings'), findsOneWidget);
    });

    testWidgets('Verification view shows the review queue and actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpConsole(tester);

      // Switch to the Verification view via the sidebar.
      await tester.tap(find.text('Verification'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('OPERATIONS / VERIFICATION'), findsOneWidget);
      expect(find.text('Review queue'), findsOneWidget);
      // Reference review actions.
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Request Changes'), findsOneWidget);
      expect(find.text('Approve Car'), findsOneWidget);
    });
  });
}
