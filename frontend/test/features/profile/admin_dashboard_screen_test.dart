import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/profile/presentation/admin_dashboard_screen.dart';

void main() {
  group('AdminDashboardScreen Widget Tests', () {
    testWidgets(
      'renders command room tabs, dispatch rows, and KYC approve actions',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: AdminDashboardScreen())),
        );

        await tester.pumpAndSettle();

        // App bar & Tabs
        expect(find.text('Operations Command Room'), findsOneWidget);
        expect(find.text('Live Dispatch'), findsOneWidget);
        expect(find.text('Chauffeur KYC'), findsOneWidget);
        expect(find.text('Fleet Registry'), findsOneWidget);

        // KPI Metric Cards — computed from the live duty + booking stores:
        // seeded REQUESTED booking is not yet a live ceremony (0), and the
        // roster has 4 chauffeurs not OFFLINE (d1-d3 available, d5 busy).
        expect(find.text('Live Ceremonies'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);

        // Live Dispatch Tab content — sourced from the booking store.
        expect(find.text('SD-2026-0100'), findsOneWidget);
        expect(find.text('Baraat • BMW 5 Series'), findsOneWidget);
        expect(find.textContaining('Rajesh Kumar'), findsOneWidget);
        expect(find.text('AWAITING ACCEPTANCE'), findsOneWidget);

        // Switch to Chauffeur KYC Tab
        await tester.tap(find.text('Chauffeur KYC'));
        await tester.pumpAndSettle();

        expect(find.text('Gurpreet Singh'), findsOneWidget);
        expect(find.text('Harish Rawat'), findsOneWidget);
        expect(find.text('Approve KYC'), findsWidgets);

        // Tap 'Approve KYC' for first applicant
        await tester.tap(find.text('Approve KYC').first);
        await tester.pumpAndSettle();

        expect(find.text('APPROVED'), findsOneWidget);

        // Switch to Fleet Registry Tab
        await tester.tap(find.text('Fleet Registry'));
        await tester.pumpAndSettle();

        expect(find.text('Mercedes-Benz S-Class'), findsOneWidget);
        expect(find.text('Rolls-Royce Ghost'), findsOneWidget);
      },
    );
  });
}
