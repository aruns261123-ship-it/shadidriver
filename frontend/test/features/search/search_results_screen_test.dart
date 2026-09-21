import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/search/presentation/search_results_screen.dart';

void main() {
  testWidgets('SearchResultsScreen displays results count when loaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SearchResultsScreen())),
    );

    // Initial loading
    expect(find.text('Searching for your royal ride...'), findsOneWidget);

    // Wait for mock search to complete (600ms delay in mock repo)
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump();

    // Verify result count (our mock repo has 7 vehicles by default)
    expect(find.textContaining('found', skipOffstage: false), findsOneWidget);
  });

  testWidgets('SearchResultsScreen shows filters chip', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SearchResultsScreen())),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Filters', skipOffstage: false), findsOneWidget);
  });
}
