import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/app.dart';
import 'package:shadidriver/core/theme/shadi_scroll_behavior.dart';

void main() {
  group('ShadiScrollBehavior Unit Tests', () {
    const behavior = ShadiScrollBehavior();

    testWidgets('getScrollPhysics returns ClampingScrollPhysics', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final physics = behavior.getScrollPhysics(context);
              expect(physics, isA<ClampingScrollPhysics>());
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets(
      'buildOverscrollIndicator returns child directly without stretch or glow',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                const testChild = Text('Child Widget');
                const details = ScrollableDetails(
                  direction: AxisDirection.down,
                );
                final result = behavior.buildOverscrollIndicator(
                  context,
                  testChild,
                  details,
                );
                expect(identical(result, testChild), isTrue);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );
  });

  group('Global ScrollBehavior Integration Tests', () {
    testWidgets(
      'Scrollable content in MaterialApp uses ShadiScrollBehavior with clamped boundary',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            scrollBehavior: const ShadiScrollBehavior(),
            home: Scaffold(
              body: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) =>
                    SizedBox(height: 60, child: Text('Item $index')),
              ),
            ),
          ),
        );

        // Verify no StretchingOverscrollIndicator or GlowingOverscrollIndicator in tree
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        expect(find.byType(GlowingOverscrollIndicator), findsNothing);

        // Verify normal scrolling works
        expect(find.text('Item 0'), findsOneWidget);
        expect(find.text('Item 30'), findsNothing);

        // Drag up to scroll down
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();

        expect(find.text('Item 0'), findsNothing);
        expect(find.text('Item 10'), findsOneWidget);

        // Drag beyond top boundary (overscroll drag)
        await tester.drag(find.byType(ListView), const Offset(0, 1000));
        await tester.pumpAndSettle();

        // Content should clamp at top, not stretch
        expect(find.text('Item 0'), findsOneWidget);
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      },
    );

    testWidgets(
      'ShadiDriverApp root configures ShadiScrollBehavior on MaterialApp.router',
      (tester) async {
        await tester.pumpWidget(const ProviderScope(child: ShadiDriverApp()));

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.scrollBehavior, isA<ShadiScrollBehavior>());
      },
    );
  });
}
