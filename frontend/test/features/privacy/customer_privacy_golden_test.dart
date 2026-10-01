import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/bookings/domain/entities/guest_fleet_selection.dart';
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

/// GOLDEN COVERAGE FOR THE CUSTOMER SURFACES.
///
/// Every golden is produced from the SAME sentinel-laden fixtures the privacy
/// widget tests use, and the privacy assertion runs immediately before the
/// image is compared. So a golden that visually contains a chauffeur name,
/// partner identity, plate or internal note is impossible: the test fails on
/// the text/semantics assertion first, with a readable message.
///
/// Determinism: the shipped fonts are loaded, the viewport is pinned to
/// 390x844 @3x, text scale 1.0, locale en_US, and the fixtures use fixed local
/// dates. Nothing touches the network, the database or a live clock — which is
/// also why `BookingDetailScreen` (whose countdown ticker repaints every
/// second) is covered by the privacy widget test but deliberately has no
/// golden.
const _boundaryKey = Key('privacy_surface');

void main() {
  setUpAll(loadShadiFonts);

  final sentinelBooks = SentinelBookingRepository();
  final sentinelVehicles = SentinelVehicleRepository();

  Future<void> expectGolden(
    WidgetTester tester,
    String fileName, {
    required String surface,
  }) async {
    expectNoPrivateSentinels(tester, surface: surface);
    await expectLater(
      find.byKey(_boundaryKey),
      matchesGoldenFile('goldens/$fileName'),
    );
  }

  testWidgets('customer_vehicle_card', (tester) async {
    await pumpPrivacySurface(
      tester,
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ShadiVehicleCard(
          viewModel: VehicleCardViewModel.fromEntity(dangerousVehicleSummary()),
          onTap: () {},
          onAddToSelection: () {},
        ),
      ),
      decodeImages: true,
    );
    await expectGolden(tester, 'customer_vehicle_card.png',
        surface: 'vehicle card');
  });

  testWidgets('customer_vehicle_details', (tester) async {
    await pumpPrivacySurface(
      tester,
      const VehicleDetailsScreen(vehicleId: 'veh-1'),
      decodeImages: true,
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(sentinelVehicles),
        favoritesRepositoryProvider.overrideWithValue(
          MockFavoritesRepository(vehicles: sentinelVehicles),
        ),
      ],
    );
    await expectGolden(tester, 'customer_vehicle_details.png',
        surface: 'vehicle details');
  });

  testWidgets('customer_cart', (tester) async {
    // The guest selection (cart) carries the composed fleet; the draft summary
    // card below it is the customer-visible cart content (cars + fare).
    await pumpPrivacySurface(
      tester,
      SingleChildScrollView(
        child: Column(
          children: [
            BookingDraftSummaryCard(
              draft: dangerousBookingDraft(),
              onDismiss: () {},
            ),
            const SizedBox(height: 12),
            const GuestSelectionBar(
              selection: GuestFleetSelection(
                lines: [
                  GuestFleetLine(
                    vehicleTypeId: 'VT_BMW5',
                    displayName: 'BMW 5 Series',
                    vehicleClass: 'Luxury Sedan',
                    seatingCapacity: 4,
                    quantity: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await expectGolden(tester, 'customer_cart.png', surface: 'cart');
  });

  testWidgets('customer_booking_review', (tester) async {
    await pumpPrivacySurface(
      tester,
      const BookingReviewScreen(draftId: 'draft_private_1'),
      overrides: [
        bookingRepositoryProvider.overrideWithValue(sentinelBooks),
      ],
    );
    await expectGolden(tester, 'customer_booking_review.png',
        surface: 'booking review');
  });

  testWidgets('customer_booking_confirmation', (tester) async {
    await pumpPrivacySurface(
      tester,
      const BookingResultScreen(bookingId: 'bk_private_1'),
      decodeImages: true,
      overrides: [
        bookingRepositoryProvider.overrideWithValue(sentinelBooks),
      ],
    );
    await expectGolden(tester, 'customer_booking_confirmation.png',
        surface: 'booking confirmation');
  });

  testWidgets('customer_group_booking_detail', (tester) async {
    await pumpPrivacySurface(
      tester,
      const GroupBookingDetailScreen(groupBookingId: 'grp_private_1'),
      decodeImages: true,
      overrides: [
        bookingRepositoryProvider.overrideWithValue(sentinelBooks),
      ],
    );
    await expectGolden(tester, 'customer_group_booking_detail.png',
        surface: 'group booking detail');
  });

  testWidgets('customer_fare_breakdown', (tester) async {
    await pumpPrivacySurface(
      tester,
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: BookingDraftSummaryCard(
          draft: dangerousBookingDraft(),
          onDismiss: () {},
        ),
      ),
    );
    await expectGolden(tester, 'customer_fare_breakdown.png',
        surface: 'fare breakdown');
  });

  testWidgets('customer_booking_history', (tester) async {
    await pumpPrivacySurface(
      tester,
      const CustomerBookingsScreen(),
      overrides: [
        bookingRepositoryProvider.overrideWithValue(sentinelBooks),
      ],
    );
    await expectGolden(tester, 'customer_booking_history.png',
        surface: 'booking history');
  });
}
