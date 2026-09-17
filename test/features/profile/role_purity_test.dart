import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/profile/presentation/customer_account_center_screen.dart';
import 'package:shadidriver/features/drivers/presentation/driver_account_center_screen.dart';
import 'package:shadidriver/features/drivers/presentation/driver_dashboard_screen.dart';
import 'package:shadidriver/features/profile/presentation/admin_account_center_screen.dart';
import 'package:shadidriver/features/profile/presentation/admin_dashboard_screen.dart';

void main() {
  group('Role Purity & Cross-Role Switcher Removal Tests', () {
    testWidgets(
      'CustomerAccountCenterScreen is role-pure without cross-role switchers',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: CustomerAccountCenterScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Role Badge is present
        expect(find.text('CUSTOMER'), findsOneWidget);

        // Verify NO cross-role navigation or swap icons
        expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
        expect(find.text('Switch to Chauffeur Console'), findsNothing);
        expect(find.text('Admin Operations Console'), findsNothing);
        expect(find.text('Switch to Driver Portal'), findsNothing);

        // Verify Customer-specific actions are present
        expect(find.text('Edit Royal Profile'), findsOneWidget);
        expect(find.text('Saved Addresses'), findsOneWidget);
        expect(find.text('Sign Out'), findsOneWidget);

        // Verify Sign Out opens confirmation dialog
        await tester.tap(find.text('Sign Out'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('Are you sure you want to end your ceremonial session?'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'DriverAccountCenterScreen is role-pure without customer switchers',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: DriverAccountCenterScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Chauffeur Role Badge is present
        expect(find.text('CHAUFFEUR'), findsOneWidget);

        // Verify NO cross-role navigation or swap icons
        expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
        expect(find.text('Switch to Customer View'), findsNothing);
        expect(find.text('Switch Portal'), findsNothing);

        // Verify Driver-specific actions are present
        expect(find.text('Chauffeur Support Desk'), findsOneWidget);
        expect(find.text('Sign Out of Chauffeur Console'), findsOneWidget);

        // Verify Sign Out opens confirmation dialog
        await tester.tap(find.text('Sign Out of Chauffeur Console'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text(
            'Are you sure you want to go offline and end your chauffeur duty session?',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'DriverDashboardScreen does not render cross-role switch button',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: DriverDashboardScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify NO cross-role navigation or swap icons in dashboard
        expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
        expect(find.text('Switch to Customer View'), findsNothing);
      },
    );

    testWidgets(
      'AdminAccountCenterScreen is role-pure without customer switchers',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: AdminAccountCenterScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Admin Role Badge is present
        expect(find.text('OPERATIONS ADMIN'), findsOneWidget);

        // Verify NO cross-role navigation or swap icons
        expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
        expect(find.text('Return to Customer View'), findsNothing);
        expect(find.text('Switch to Customer View'), findsNothing);

        // Verify Admin-specific actions are present
        expect(find.text('System & Security Help Desk'), findsOneWidget);
        expect(find.text('Sign Out of Operations Console'), findsOneWidget);

        // Verify Sign Out opens confirmation dialog
        await tester.tap(find.text('Sign Out of Operations Console'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text(
            'Are you sure you want to lock the control room and end your administrative session?',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AdminDashboardScreen does not render cross-role switch button',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: AdminDashboardScreen())),
        );

        await tester.pumpAndSettle();

        // Verify NO cross-role navigation or swap icons in dashboard
        expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
        expect(find.text('Switch to Customer View'), findsNothing);
      },
    );
  });
}
