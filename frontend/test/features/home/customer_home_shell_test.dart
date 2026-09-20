import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/features/home/presentation/customer_home_shell.dart';

void main() {
  testWidgets('CustomerHomeShell renders bottom navigation correctly', (
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

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets); // One in nav bar
    expect(find.text('Search'), findsWidgets);

    // Navigate to Search
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Search Content'), findsOneWidget);
  });
}
