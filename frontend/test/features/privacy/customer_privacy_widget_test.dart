import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_summary.dart';
import 'package:shadidriver/features/bookings/domain/entities/guest_fleet_selection.dart';
import 'package:shadidriver/features/bookings/presentation/booking_detail_screen.dart';
import 'package:shadidriver/features/bookings/presentation/booking_result_screen.dart';
import 'package:shadidriver/features/bookings/presentation/booking_review_screen.dart';
import 'package:shadidriver/features/bookings/presentation/customer_bookings_screen.dart';
import 'package:shadidriver/features/bookings/presentation/group_booking_detail_screen.dart';
import 'package:shadidriver/features/bookings/presentation/widgets/booking_draft_summary_card.dart';
import 'package:shadidriver/features/bookings/presentation/widgets/guest_selection_bar.dart';
import 'package:shadidriver/features/favorites/data/mock_favorites_repository.dart';
import 'package:shadidriver/features/home/presentation/view_models/vehicle_card_view_model.dart';
import 'package:shadidriver/features/vehicles/presentation/vehicle_details_screen.dart';
import 'package:shadidriver/features/vehicles/presentation/widgets/shadi_vehicle_card.dart';

import '../../support/privacy/privacy_sentinels.dart';
import '../../support/privacy/sentinel_fixtures.dart';

/// PRESENTATION-LAYER PRIVACY REGRESSION HARNESS (customer surfaces).
///
/// Every surface below is rendered with fixtures whose PRIVATE fields carry
/// loud sentinels (chauffeur name/phone/email/address, partner identity,
/// registration plate, internal note). The tests then assert:
///
///   1. the customer-safe fields the surface is FOR are present, and
///   2. no sentinel is present anywhere the customer can read it — widget
///      tree, rich text, tooltip, editable field, semantics widget or the
///      compiled accessibility tree.
///
/// Admin/driver surfaces are deliberately NOT covered here: they are
/// authorized to see operational detail and must keep their own contracts.
void main() {
  setUpAll(loadShadiFonts);

  final sentinelBooks = SentinelBookingRepository();
  final sentinelVehicles = SentinelVehicleRepository();

  List<Override> bookingOverrides() => [
    bookingRepositoryProvider.overrideWithValue(sentinelBooks),
  ];

  List<Override> vehicleOverrides() => [
    vehicleRepositoryProvider.overrideWithValue(sentinelVehicles),
    favoritesRepositoryProvider.overrideWithValue(
      MockFavoritesRepository(vehicles: sentinelVehicles),
    ),
  ];

  group('harness self-check', () {
    test('every fixture really carries a private sentinel', () {
      assertFixtureIsDangerous();
    });

    testWidgets('the scanner CATCHES a planted sentinel (no vacuous pass)', (
      tester,
    ) async {
      await pumpPrivacySurface(
        tester,
        const Text(PrivacySentinels.driverName),
      );
      expect(
        () => expectNoPrivateSentinels(tester, surface: 'planted leak probe'),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets('the scanner ALSO sees accessibility-only leaks', (
      tester,
    ) async {
      // Nothing is painted as text, yet a screen reader would announce it.
      await pumpPrivacySurface(
        tester,
        Semantics(
          label: PrivacySentinels.driverPhone,
          child: const SizedBox(width: 80, height: 80),
        ),
      );

      expect(find.textContaining(PrivacySentinels.driverPhone), findsNothing);
      expect(
        () => expectNoPrivateSentinels(
          tester,
          surface: 'semantics-only leak probe',
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets('the accessibility tree really is populated (scan is not a '
        'no-op)', (tester) async {
      await pumpPrivacySurface(
        tester,
        const BookingDetailScreen(bookingId: 'bk_private_1'),
        overrides: bookingOverrides(),
      );

      final announced = semanticsTreeStrings(tester).join(' | ');
      expect(announced, contains('Booking Details'));
      expect(announced, contains('SD-2026-0101'));
      expect(PrivacySentinels.pattern.hasMatch(announced), isFalse);
    });
  });

  group('vehicle card', () {
    testWidgets('renders the car, the fare and the verification trust line', (
      tester,
    ) async {
      final viewModel = VehicleCardViewModel.fromEntity(
        dangerousVehicleSummary(),
      );

      await pumpPrivacySurface(
        tester,
        SingleChildScrollView(
          child: ShadiVehicleCard(
            viewModel: viewModel,
            onTap: () {},
            onAddToSelection: () {},
          ),
        ),
      );

      expect(find.text('BMW 5 Series'), findsOneWidget);
      expect(find.text('ESTIMATED FARE'), findsOneWidget);
      expect(
        find.textContaining('verified by ShadiDriver'),
        findsOneWidget,
      );

      // The customer-facing view model must not carry the private plate.
      expect(PrivacySentinels.isPresentIn(viewModel.subtitle), isFalse);
      expect(PrivacySentinels.isPresentIn(viewModel.title), isFalse);
      expectNoPrivateSentinels(tester, surface: 'vehicle card');
    });
  });

  group('vehicle details', () {
    testWidgets('renders specs, trust and pricing without internal identity', (
      tester,
    ) async {
      await pumpPrivacySurface(
        tester,
        const VehicleDetailsScreen(vehicleId: 'veh-1'),
        overrides: vehicleOverrides(),
      );

      expect(find.text('BMW 5 Series'), findsOneWidget);
      expect(
        find.text('Vehicle and chauffeur verified by ShadiDriver'),
        findsOneWidget,
      );
      expect(find.text('Add to Cart'), findsOneWidget);
      expect(find.textContaining('Calculated rate'), findsOneWidget);

      expectNoPrivateSentinels(tester, surface: 'vehicle details');
    });
  });

  group('cart (guest selection bar)', () {
    testWidgets('shows the selected cars and never internal fleet data', (
      tester,
    ) async {
      const selection = GuestFleetSelection(
        lines: [
          GuestFleetLine(
            vehicleTypeId: 'VT_INNOVA_CRYSTA',
            displayName: 'Toyota Innova Crysta',
            vehicleClass: 'Executive MPV',
            seatingCapacity: 6,
            quantity: 2,
          ),
        ],
      );

      await pumpPrivacySurface(
        tester,
        const Align(
          alignment: Alignment.bottomCenter,
          child: GuestSelectionBar(selection: selection),
        ),
      );

      expect(find.text('2 Cars Selected'), findsOneWidget);
      expect(find.text('Toyota Innova Crysta × 2'), findsOneWidget);
      expect(find.text('Review Selection'), findsOneWidget);

      expectNoPrivateSentinels(tester, surface: 'cart selection bar');
    });
  });

  group('fare breakdown (draft summary card)', () {
    testWidgets('itemises fare and advance without leaking identity', (
      tester,
    ) async {
      await pumpPrivacySurface(
        tester,
        SingleChildScrollView(
          child: BookingDraftSummaryCard(
            draft: dangerousBookingDraft(),
            onDismiss: () {},
          ),
        ),
      );

      expect(find.text('Vehicle'), findsOneWidget);
      expect(find.text('Estimated Total'), findsOneWidget);
      expect(find.text('₹25,000'), findsOneWidget);
      expect(find.text('Advance Token'), findsOneWidget);
      expect(find.text('₹5,000'), findsOneWidget);

      expectNoPrivateSentinels(tester, surface: 'fare breakdown');
    });
  });

  group('booking review', () {
    testWidgets('reviews the itinerary and fare with no chauffeur identity', (
      tester,
    ) async {
      await pumpPrivacySurface(
        tester,
        const BookingReviewScreen(draftId: 'draft_private_1'),
        overrides: bookingOverrides(),
      );

      expect(find.text('Review Reservation'), findsOneWidget);
      expect(find.text('BMW 5 Series'), findsOneWidget);
      expect(find.text('Fare Summary'), findsOneWidget);
      expect(
        find.textContaining('assigned & verified by ShadiDriver'),
        findsOneWidget,
      );
      expect(find.text('Submit Booking Request'), findsOneWidget);

      expectNoPrivateSentinels(tester, surface: 'booking review');
    });
  });

  group('booking confirmation', () {
    testWidgets('confirms the request without revealing who drives', (
      tester,
    ) async {
      await pumpPrivacySurface(
        tester,
        const BookingResultScreen(bookingId: 'bk_private_1'),
        overrides: bookingOverrides(),
      );

      expect(find.text('Request Submitted'), findsOneWidget);
      expect(
        find.text('Booking Request Received • Awaiting Confirmation'),
        findsOneWidget,
      );
      expect(find.text('SD-2026-0101'), findsOneWidget);

      expectNoPrivateSentinels(tester, surface: 'booking confirmation');
    });
  });

  group('booking detail', () {
    testWidgets('shows status, itinerary and the platform assurance only', (
      tester,
    ) async {
      await pumpPrivacySurface(
        tester,
        const BookingDetailScreen(bookingId: 'bk_private_1'),
        overrides: bookingOverrides(),
      );

      expect(find.text('Booking Details'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('SD-2026-0101'), findsOneWidget);
      expect(
        find.textContaining('verified by ShadiDriver'),
        findsOneWidget,
      );

      expectNoPrivateSentinels(tester, surface: 'booking detail');
    });

    testWidgets('the post-ceremony review surface carries no identity', (
      tester,
    ) async {
      // COMPLETED + unreviewed renders the review CTA; the sheet it opens is
      // part of the customer presentation layer too.
      await pumpPrivacySurface(
        tester,
        const BookingDetailScreen(bookingId: 'bk_private_1'),
        overrides: [
          bookingRepositoryProvider.overrideWithValue(
            SentinelCompletedBookingRepository(),
          ),
        ],
      );

      final reviewCta = find.byKey(const Key('detail_review_cta'));
      expect(reviewCta, findsOneWidget);
      await tester.ensureVisible(reviewCta);
      await tester.pumpAndSettle();
      await tester.tap(reviewCta);
      await tester.pumpAndSettle();

      expect(find.textContaining('Rate'), findsWidgets);
      expectNoPrivateSentinels(tester, surface: 'post-ceremony review sheet');
    });
  });

  group('group booking detail', () {
    testWidgets('lists the convoy and neutral chauffeur state only', (
      tester,
    ) async {
      await pumpPrivacySurface(
        tester,
        const GroupBookingDetailScreen(groupBookingId: 'grp_private_1'),
        overrides: bookingOverrides(),
      );

      expect(find.text('SD-GRP-2026-000123'), findsOneWidget);
      expect(find.text('Vehicle Assignments (2)'), findsOneWidget);
      expect(
        find.text('Chauffeur arranged by ShadiDriver'),
        findsNWidgets(2),
      );
      expect(find.text('Pricing Summary'), findsOneWidget);

      expectNoPrivateSentinels(tester, surface: 'group booking detail');
    });
  });

  group('booking history', () {
    testWidgets('lists the customer self’s journeys, never the chauffeur', (
      tester,
    ) async {
      await pumpPrivacySurface(
        tester,
        const CustomerBookingsScreen(),
        overrides: bookingOverrides(),
      );

      expect(find.text('My Ceremonial Journeys'), findsOneWidget);
      expect(find.text('SD-2026-0101'), findsOneWidget);
      expect(
        find.textContaining('verified by ShadiDriver'),
        findsOneWidget,
      );

      expectNoPrivateSentinels(tester, surface: 'booking history');
    });
  });
}

/// Booking repository variant for the COMPLETED/unreviewed review flow.
class SentinelCompletedBookingRepository extends SentinelBookingRepository {
  @override
  Future<Result<BookingSummary>> getBookingById(String bookingId) async =>
      Result.success(dangerousBookingSummary(status: 'COMPLETED'));
}
