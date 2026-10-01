import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

void main() {
  Widget createWidgetToTest({required String initialLocation}) {
    final router = createShadiRouter(initialLocation: initialLocation);
    return ProviderScope(
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(MockVehicleRepository()),
        driverRepositoryProvider.overrideWithValue(MockDriverRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('Vehicle Details flow (reference Car-details surface)', () {
    testWidgets(
      'VehicleDetailsScreen loads Audi A6 (v2) specs and trust info',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerVehicleDetailsPath('v2'),
          ),
        );

        await tester.pumpAndSettle();

        // Reference layout: eyebrow (vehicle class), Playfair title, spec grid
        // cells and the rate card.
        expect(find.text('Audi A6'), findsWidgets);
        expect(
          find.text('PREMIUM SEDAN', skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('4 Seats'), findsOneWidget);
        expect(find.text('Pricing'), findsOneWidget);
        expect(find.text('Calculated rate'), findsOneWidget);
        // The single-vehicle booking entry remains reachable.
        expect(
          find.text('Book this car now', skipOffstage: false),
          findsOneWidget,
        );
      },
    );

    testWidgets('VehicleDetailsScreen loads Toyota Fortuner (v3) specs', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetToTest(
          initialLocation: RoutePaths.customerVehicleDetailsPath('v3'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Toyota Fortuner'), findsWidgets);
      expect(find.text('PREMIUM SUV', skipOffstage: false), findsOneWidget);
      expect(find.text('7 Seats'), findsOneWidget);
    });

    testWidgets(
      'VehicleDetailsScreen displays error state for invalid vehicle ID',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerVehicleDetailsPath(
              'invalid_id',
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Vehicle specifications could not be found.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the customer vehicle page shows the ShadiDriver assurance and NO chauffeur identity',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerVehicleDetailsPath('v2'),
          ),
        );
        await tester.pumpAndSettle();

        // Trust is expressed by the company, not by a person profile.
        expect(
          find.text('ShadiDriver Assurance', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text(
            'Vehicle and chauffeur verified by ShadiDriver',
            skipOffstage: false,
          ),
          findsOneWidget,
        );

        // No chauffeur surface may exist on a customer screen.
        expect(find.text('Assigned Chauffeur'), findsNothing);
        expect(find.text('View Profile'), findsNothing);
        expect(find.textContaining('Ceremonies'), findsNothing);
      },
    );

    testWidgets(
      'a customer cannot reach a chauffeur profile route',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: '/customer/chauffeurs/d1',
          ),
        );
        await tester.pumpAndSettle();

        // The route no longer exists: it must not resolve to a chauffeur page.
        expect(find.text('Rajesh Kumar'), findsNothing);
        expect(find.textContaining('Page not found'), findsOneWidget);
      },
    );

    testWidgets(
      'Search Results -> View Details -> Vehicle Details -> booking entry',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(initialLocation: RoutePaths.customerSearchResults),
        );

        await tester.pumpAndSettle();

        // The reference card taps through from anywhere — the whole card is
        // the affordance. Open the first card by tapping its title (BMW
        // 5 Series is the first mock row).
        final firstCardTitle = find.text('BMW 5 Series').first;
        await tester.ensureVisible(firstCardTitle);
        await tester.pumpAndSettle();
        await tester.tap(firstCardTitle);
        await tester.pumpAndSettle();

        // The reference detail surface shows the Add-to-Cart bar plus the
        // single-vehicle booking link.
        expect(
          find.text('Add to Cart', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text('Book this car now', skipOffstage: false),
          findsOneWidget,
        );

        // The existing booking-entry flow remains reachable.
        await tester.tap(find.text('Book this car now'));
        await tester.pumpAndSettle();

        expect(find.text('Booking Experience'), findsOneWidget);
        expect(find.textContaining('Vehicle ID:'), findsOneWidget);
      },
    );
  });
}
