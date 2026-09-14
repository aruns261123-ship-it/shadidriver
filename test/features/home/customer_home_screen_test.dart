import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/home/presentation/customer_home_screen.dart';
import 'package:shadidriver/features/home/presentation/widgets/shadi_search_card.dart';
import 'package:shadidriver/features/home/presentation/widgets/shadi_urgent_dispatch_card.dart';
import 'package:shadidriver/features/vehicles/presentation/widgets/shadi_vehicle_card.dart';

void main() {
  testWidgets('CustomerHomeScreen renders all production sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CustomerHomeScreen())),
    );

    // Initial loading state
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Wait for data
    await tester.pumpAndSettle();

    // Verify Search Card
    expect(find.byType(ShadiSearchCard), findsOneWidget);

    // Verify Urgent Dispatch
    expect(find.byType(ShadiUrgentDispatchCard), findsOneWidget);

    // Scroll to see vehicle cards
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    // Verify Featured Fleet (from mock)
    expect(
      find.text('Featured for Your Celebration', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(ShadiVehicleCard, skipOffstage: false), findsWidgets);

    // Verify Trust Section
    expect(find.text('Royal Assurance', skipOffstage: false), findsOneWidget);
  });
}
