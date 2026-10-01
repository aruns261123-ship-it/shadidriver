import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/home/presentation/customer_home_screen.dart';
import 'package:shadidriver/features/home/presentation/widgets/customer_home_hero.dart';
import 'package:shadidriver/features/home/presentation/widgets/route_booking_panel.dart';
import 'package:shadidriver/features/home/presentation/widgets/popular_category_card.dart';
import 'package:shadidriver/features/home/presentation/widgets/shadi_urgent_dispatch_card.dart';
import 'package:shadidriver/features/vehicles/presentation/widgets/shadi_vehicle_card.dart';

import '../../helpers/mock_env.dart';

void main() {
  testWidgets('CustomerHomeScreen renders the reference structure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mockModeOverrides(),
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );

    // Initial loading state
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Wait for data
    await tester.pumpAndSettle();

    // Reference hero + booking panel replace the old white appbar/search card
    expect(find.byType(CustomerHomeHero), findsOneWidget);
    expect(find.byType(RouteBookingPanel), findsOneWidget);
    expect(find.text('Find Cars'), findsOneWidget);

    // One Way / Both Way segmented control
    expect(find.text('One Way'), findsOneWidget);
    expect(find.text('Both Way'), findsOneWidget);

    // Popular categories rail
    expect(find.byType(PopularCategoryCard, skipOffstage: false), findsWidgets);

    // Scroll to see vehicle cards
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    // Urgent dispatch remains part of the feed
    expect(find.byType(ShadiUrgentDispatchCard, skipOffstage: false), findsOneWidget);

    // Featured fleet cards (suggested + featured list)
    expect(find.byType(ShadiVehicleCard, skipOffstage: false), findsWidgets);

    // Trust section
    expect(find.text('Royal Assurance', skipOffstage: false), findsOneWidget);
  });
}
