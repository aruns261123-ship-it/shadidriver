import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/presentation/booking_detail_screen.dart';

void main() {
  group('BookingDetailScreen Widget Tests', () {
    testWidgets(
      'renders confirmed booking with Ceremony Start Code OTP and timeline',
      (tester) async {
        final mockBookingRepo = MockBookingRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
            ],
            child: const MaterialApp(
              home: BookingDetailScreen(bookingId: 'b_mock_1'),
            ),
          ),
        );

        // Loading state
        expect(find.byType(BookingDetailScreen), findsOneWidget);
        await tester.pumpAndSettle();

        // Status header & reference
        expect(find.text('CONFIRMED'), findsOneWidget);
        expect(find.text('SHD-2026-DLH-0192'), findsOneWidget);

        // Ceremony details & itinerary
        expect(find.text('SVC_BARAAT Ceremony'), findsOneWidget);
        expect(
          find.text('The Oberoi, Dr Zakir Hussain Marg, New Delhi'),
          findsWidgets,
        );

        // Timeline
        expect(find.text('Ceremonial Journey'), findsOneWidget);
        expect(find.text('Request Submitted'), findsOneWidget);
        expect(find.text('Reservation Secured'), findsOneWidget);

        // Ceremony Start Code OTP badge is rendered
        expect(find.text('Ceremony Start Code'), findsOneWidget);
        expect(
          find.byKey(const Key('ceremony_start_otp_badge')),
          findsOneWidget,
        );
        expect(find.text('1234'), findsOneWidget);
      },
    );

    testWidgets('renders call chauffeur action and handles tap', (
      tester,
    ) async {
      final mockBookingRepo = MockBookingRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
          ],
          child: const MaterialApp(
            home: BookingDetailScreen(bookingId: 'bk_mock_req_1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Seeded bk_mock_req_1 has chauffeurName 'Rajesh Kumar'
      expect(find.text('Rajesh Kumar'), findsOneWidget);
      final callButton = find.byKey(const Key('detail_call_chauffeur_cta'));
      expect(callButton, findsOneWidget);

      await tester.tap(callButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Connecting to Chauffeur Rajesh Kumar…'),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders pay advance token button when status is DRIVER_ACCEPTED',
      (tester) async {
        final mockBookingRepo = MockBookingRepository();
        // Driver accepts booking
        mockBookingRepo.markBookingAccepted('bk_mock_req_1');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
            ],
            child: const MaterialApp(
              home: BookingDetailScreen(bookingId: 'bk_mock_req_1'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Status should be DRIVER ACCEPTED (formatted without underscore by ShadiStatusBadge)
        expect(find.text('DRIVER ACCEPTED'), findsOneWidget);
        expect(find.byKey(const Key('detail_pay_cta')), findsOneWidget);
      },
    );

    testWidgets('renders review CTA when booking is COMPLETED and unreviewed', (
      tester,
    ) async {
      final mockBookingRepo = MockBookingRepository();
      // Driver completes booking
      mockBookingRepo.markBookingCompleted('b_mock_1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
          ],
          child: const MaterialApp(
            home: BookingDetailScreen(bookingId: 'b_mock_1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.byKey(const Key('detail_review_cta')), findsOneWidget);
    });
  });
}
