import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/search/presentation/search_results_screen.dart';

import '../../helpers/mock_env.dart';

void main() {
  testWidgets('SearchResultsScreen displays eligibility summary when loaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mockModeOverrides(),
        child: const MaterialApp(home: SearchResultsScreen()),
      ),
    );

    // Initial loading
    expect(find.text('Finding eligible cars…'), findsOneWidget);

    // Wait for mock search to complete (600ms delay in mock repo)
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump();

    // Reference summary: "<n> cars eligible for your trip"
    expect(
      find.textContaining('eligible for your trip', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('SearchResultsScreen shows filters chip', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mockModeOverrides(),
        child: const MaterialApp(home: SearchResultsScreen()),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Filters', skipOffstage: false), findsOneWidget);
  });
}
