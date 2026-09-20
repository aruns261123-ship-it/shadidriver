import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/app.dart';

void main() {
  testWidgets(
    'ShadiDriverApp smoke test — app shell initializes without errors',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: ShadiDriverApp()));

      // pumpAndSettle drives all pending timers to completion, including:
      //   • GoRouter's async redirect (resolves /splash route)
      // Note: SplashScreen restores session asynchronously without artificial delay.
      // We pump for a sufficient duration to let timers fire.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

      // No uncaught exceptions during the startup sequence.
      expect(tester.takeException(), isNull);
    },
  );
}
