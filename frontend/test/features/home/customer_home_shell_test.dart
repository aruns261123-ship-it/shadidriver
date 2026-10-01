import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/features/home/presentation/customer_home_shell.dart';

void main() {
  testWidgets('CustomerHomeShell renders the reference bottom navigation', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RoutePaths.customerHome,
      routes: [
        ShellRoute(
          builder: (context, state, child) => CustomerHomeShell(child: child),
          routes: [
            GoRoute(
              path: RoutePaths.customerHome,
              builder: (context, state) =>
                  const Scaffold(body: Text('Home Content')),
            ),
            GoRoute(
              path: RoutePaths.customerSearch,
              builder: (context, state) =>
                  const Scaffold(body: Text('Search Content')),
            ),
          ],
        ),
      ],
    );

    // The shell is a ConsumerWidget (it hosts the persistent guest-selection
    // banner), so it must live inside a ProviderScope.
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    // The reference nav: Home · Cars · Bookings · Profile — four items, the
    // active one in burgundy with a top-edge indicator.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Cars'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Messages'), findsNothing);
    expect(find.text('Search'), findsNothing);

    // Navigate to Cars (the search tab).
    await tester.tap(find.text('Cars'));
    await tester.pumpAndSettle();

    expect(find.text('Search Content'), findsOneWidget);
  });
}
