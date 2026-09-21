import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/presentation/customer_bookings_screen.dart';

void main() {
  group('CustomerBookingsScreen Widget Tests', () {
    testWidgets('renders tabs, seeded booking card, and details', (
      tester,
    ) async {
      final mockBookingRepo = MockBookingRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
          ],
          child: const MaterialApp(home: CustomerBookingsScreen()),
        ),
      );

      // Initial loading state
      expect(find.byType(CustomerBookingsScreen), findsOneWidget);
      await tester.pumpAndSettle();

      // Tabs
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);

      // Seeded booking card contents
      expect(find.text('SD-2026-0100'), findsOneWidget);
      expect(find.text('Baraat Ceremony'), findsOneWidget);
      expect(find.text('BMW 5 Series'), findsOneWidget);
      expect(find.text('Awaiting Confirmation'), findsOneWidget);
      expect(
        find.textContaining('Assigned Chauffeur: Rajesh Kumar'),
        findsOneWidget,
      );

      // Tap on 'Completed' tab
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      // Empty state for Completed
      expect(find.text('No Past Ceremonies'), findsOneWidget);
      expect(find.text('Explore Fleet'), findsOneWidget);
    });
  });
}
