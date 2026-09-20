import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/search/presentation/search_screen.dart';

void main() {
  testWidgets('SearchScreen renders all input fields', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SearchScreen())),
    );

    expect(find.text('Pickup Location'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Event Date'), findsOneWidget);
    expect(find.text('Ceremony / Occasion'), findsOneWidget);
    expect(find.text('Search Chauffeurs'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('SearchScreen updates passenger count', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SearchScreen())),
    );

    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('5'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });
}
