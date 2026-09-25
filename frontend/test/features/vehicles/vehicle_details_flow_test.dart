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

  group('Vehicle Details & Chauffeur Profile Navigation Flow Tests', () {
    testWidgets(
      'VehicleDetailsScreen loads Audi A6 (v2) specs and chauffeur info',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerVehicleDetailsPath('v2'),
          ),
        );

        // Settle async providers
        await tester.pumpAndSettle();

        // Verify Audi A6 details
        expect(find.text('Audi A6'), findsWidgets);
        expect(find.text('2024 • Premium Sedan'), findsOneWidget);
        expect(find.text('Four-Zone Deluxe Climate Control'), findsOneWidget);
        expect(find.text('Book Now'), findsOneWidget);
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
      expect(find.text('2025 • Premium SUV'), findsOneWidget);
      expect(find.text('7 Passengers'), findsOneWidget);
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
      'the customer vehicle page shows the ShadiDriver assurance panel and NO chauffeur identity',
      (tester) async {
        await tester.pumpWidget(
          createWidgetToTest(
            initialLocation: RoutePaths.customerVehicleDetailsPath('v2'),
          ),
        );
        await tester.pumpAndSettle();

        // Trust is expressed by the company, not by a person profile.
        expect(find.text('ShadiDriver Assurance'), findsOneWidget);
        expect(
          find.text('Vehicle & chauffeur verified by ShadiDriver'),
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

    testWidgets('Search Results -> View Details -> Vehicle Details -> Book Now', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetToTest(initialLocation: RoutePaths.customerSearchResults),
      );

      // Wait for search results
      await tester.pumpAndSettle();

      // Find 'View Details' button for first vehicle or tap the card
      final viewDetailsButton = find.text('View Details').first;
      expect(viewDetailsButton, findsOneWidget);

      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Verify we are on Vehicle Details screen
      expect(find.text('Book Now'), findsOneWidget);

      // Tap 'Book Now'
      await tester.tap(find.text('Book Now'));
      await tester.pumpAndSettle();

      // Verify we navigate to Booking Entry placeholder with selected vehicle ID
      expect(find.text('Booking Experience'), findsOneWidget);
      expect(find.textContaining('Vehicle ID:'), findsOneWidget);
    });
  });
}
