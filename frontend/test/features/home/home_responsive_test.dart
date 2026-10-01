import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/core/security/in_memory_secure_storage.dart';
import 'package:shadidriver/core/widgets/shadi_muhurat_countdown_ticker.dart';
import 'package:shadidriver/features/auth/data/mock_auth_repository.dart';
import 'package:shadidriver/features/home/presentation/customer_home_screen.dart';
import 'package:shadidriver/features/home/presentation/widgets/route_booking_panel.dart';
import 'package:shadidriver/features/home/presentation/widgets/shadi_urgent_dispatch_card.dart';
import 'package:shadidriver/features/search/presentation/search_results_screen.dart';

import '../../helpers/mock_env.dart';

/// Compact-phone responsiveness for the Customer Home surface.
///
/// These are deliberately NON-VACUOUS: every case lays the widget out inside
/// the home page's real 20dp horizontal padding at a real phone width, and
/// fails with the layout error text (including the overflow amount and the
/// offending widget) if anything overflows.
void main() {
  /// The widths the product must hold: a small 360dp Android phone up to a
  /// large 412dp one.
  const widths = <double>[320, 360, 375, 390, 412];

  /// Captures an error with the information the framework collected about it,
  /// so a failing case names the offending widget and its constraints instead
  /// of just quoting a pixel count.
  void collect(FlutterErrorDetails details, List<String> into) {
    final buffer = StringBuffer(details.exceptionAsString());
    if (details.context != null) buffer.write('\n${details.context}');
    final collected = details.informationCollector?.call();
    if (collected != null) {
      for (final node in collected) {
        buffer.write('\n$node');
      }
    }
    into.add(buffer.toString());
  }

  /// Runs [build] at [width] logical px with the home page's horizontal
  /// padding, and returns every ERROR the frame reported (RenderFlex overflow,
  /// clipped-and-lost content, etc.).
  Future<List<String>> layoutErrors(
    WidgetTester tester,
    Widget Function() build, {
    required double width,
    double textScale = 1.0,
    double height = 1600,
  }) async {
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => collect(details, errors);

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              // The home page's own AppSpacing.screenPadding.
              padding: const EdgeInsets.all(20),
              child: build(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    FlutterError.onError = previous;
    return errors;
  }

  /// The width a child actually gets inside the home page (page padding).
  double contentWidth(double screenWidth) => screenWidth - 40;

  group('RouteBookingPanel — compact phone', () {
    for (final width in widths) {
      testWidgets('renders with no overflow at ${width.toInt()}dp', (
        tester,
      ) async {
        final errors = await layoutErrors(
          tester,
          () => RouteBookingPanel(
            tripDirection: TripDirection.oneWay,
            onTripChanged: (_) {},
            onFindCars: () {},
          ),
          width: width,
        );
        expect(errors, isEmpty, reason: errors.join('\n\n'));

        // The panel's primary action must be present and tappable.
        final cta = find.text('Find Cars');
        expect(cta, findsOneWidget);
        await tester.tap(cta);
        expect(
          tester.getSize(find.byType(RouteBookingPanel)).width,
          lessThanOrEqualTo(contentWidth(width) + 0.5),
        );
      });

      testWidgets('fields survive ${width.toInt()}dp at 1.3x text scale', (
        tester,
      ) async {
        final errors = await layoutErrors(
          tester,
          () => RouteBookingPanel(
            tripDirection: TripDirection.bothWay,
            onTripChanged: (_) {},
            onFindCars: () {},
          ),
          width: width,
          textScale: 1.3,
        );
        expect(errors, isEmpty, reason: errors.join('\n\n'));
        // No content may be silently dropped: both route fields, the trip
        // segments and the CTA are still laid out and inside the panel.
        for (final label in [
          'Use current location',
          'Enter destination',
          'One Way',
          'Both Way',
        ]) {
          final finder = find.text(label);
          expect(finder, findsOneWidget, reason: '$label must be visible');
          expect(
            tester.getSize(finder).width,
            lessThanOrEqualTo(contentWidth(width) + 0.5),
          );
        }
      });
    }

    testWidgets('trip segments stack at 320dp instead of overflowing', (
      tester,
    ) async {
      final errors = await layoutErrors(
        tester,
        () => RouteBookingPanel(
          tripDirection: TripDirection.oneWay,
          onTripChanged: (_) {},
          onFindCars: () {},
        ),
        width: 320,
      );
      expect(errors, isEmpty, reason: errors.join('\n\n'));
      expect(find.text('One Way'), findsOneWidget);
      expect(find.text('Both Way'), findsOneWidget);
    });

    testWidgets('holds at 2x text scale on a 360dp phone', (tester) async {
      final errors = await layoutErrors(
        tester,
        () => RouteBookingPanel(
          tripDirection: TripDirection.bothWay,
          onTripChanged: (_) {},
          onFindCars: () {},
        ),
        width: 360,
        textScale: 2.0,
      );
      expect(errors, isEmpty, reason: errors.join('\n\n'));
      expect(find.text('Find Cars'), findsOneWidget);
    });
  });

  group('ShadiMuhuratCountdownTicker — compact phone', () {
    for (final width in widths) {
      testWidgets('renders with no overflow at ${width.toInt()}dp', (
        tester,
      ) async {
        // The ticker animates its clock every second, so it must never be
        // pumped to settle.
        final errors = await layoutErrors(
          tester,
          () => const ShadiMuhuratCountdownTicker(
            ceremonyName: 'Today’s Auspicious Muhurat Lagna',
            venueName:
                'Vedic Wedding Astrological Window • Prime Ceremonial Hours',
          ),
          width: width,
        );
        expect(errors, isEmpty, reason: errors.join('\n\n'));

        // The countdown itself must stay on screen.
        for (final unit in ['HOURS', 'MINS', 'SECS']) {
          expect(find.text(unit), findsOneWidget);
        }
      });

      testWidgets('keeps the assurance line readable at ${width.toInt()}dp', (
        tester,
      ) async {
        final errors = await layoutErrors(
          tester,
          () => const ShadiMuhuratCountdownTicker(
            ceremonyName: 'Today’s Auspicious Muhurat Lagna',
            venueName:
                'Vedic Wedding Astrological Window • Prime Ceremonial Hours',
          ),
          width: width,
        );
        expect(errors, isEmpty, reason: errors.join('\n\n'));

        // Not clipped: the whole sentence is laid out inside the ticker.
        final assurance = find.text(
          'Royal Chauffeur on standby 45 mins prior to the holy hour',
        );
        expect(assurance, findsOneWidget);
        expect(
          tester.getSize(assurance).width,
          lessThanOrEqualTo(contentWidth(width) + 0.5),
        );
      });
    }

    testWidgets('holds at 1.3x text scale on a 360dp phone', (tester) async {
      final errors = await layoutErrors(
        tester,
        () => const ShadiMuhuratCountdownTicker(
          ceremonyName: 'Today’s Auspicious Muhurat Lagna',
          venueName:
              'Vedic Wedding Astrological Window • Prime Ceremonial Hours',
        ),
        width: 360,
        textScale: 1.3,
      );
      expect(errors, isEmpty, reason: errors.join('\n\n'));
      expect(find.text('LAGNA COUNTDOWN'), findsOneWidget);
    });
  });

  group('ShadiUrgentDispatchCard — compact phone', () {
    for (final width in widths) {
      testWidgets('renders with no overflow at ${width.toInt()}dp', (
        tester,
      ) async {
        final errors = await layoutErrors(
          tester,
          () => ShadiUrgentDispatchCard(
            availableCount: 11,
            eta: '6 mins',
            onTap: () {},
          ),
          width: width,
        );
        expect(errors, isEmpty, reason: errors.join('\n\n'));
        expect(find.text('Need a car right now?'), findsOneWidget);
        expect(find.text('11 Available'), findsOneWidget);
        expect(find.text('ETA 6 mins'), findsOneWidget);
      });

      testWidgets('description is not clipped at ${width.toInt()}dp', (
        tester,
      ) async {
        final errors = await layoutErrors(
          tester,
          () => ShadiUrgentDispatchCard(
            availableCount: 11,
            eta: '6 mins',
            onTap: () {},
          ),
          width: width,
        );
        expect(errors, isEmpty, reason: errors.join('\n\n'));
        expect(
          tester
              .getSize(
                find.text(
                  'Nearby verified chauffeurs ready for urgent wedding dispatch.',
                ),
              )
              .width,
          lessThanOrEqualTo(contentWidth(width) + 0.5),
        );
      });
    }

    testWidgets('holds at 2x text scale on a 360dp phone', (tester) async {
      final errors = await layoutErrors(
        tester,
        () => ShadiUrgentDispatchCard(
          availableCount: 11,
          eta: '6 mins',
          onTap: () {},
        ),
        width: 360,
        textScale: 2.0,
      );
      expect(errors, isEmpty, reason: errors.join('\n\n'));
      expect(find.text('Need a car right now?'), findsOneWidget);
    });
  });

  group('CustomerHomeScreen — compact phone', () {
    late InMemorySecureStorage secureStorage;
    late MockAuthRepository authRepo;

    setUp(() {
      secureStorage = InMemorySecureStorage();
      authRepo = MockAuthRepository(secureStorage, false);
    });

    /// Pumps the real Home screen inside the real router (so the CTA can be
    /// tapped for real) and returns every layout error the frames reported.
    Future<List<String>> pumpHome(WidgetTester tester, double width) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      // Restored BEFORE the caller's expect() runs: leaving the override
      // installed while asserting makes flutter_test abort with a masking
      // "_pendingExceptionDetails != null" assertion instead of the real
      // failure reason.
      FlutterError.onError = (details) => collect(details, errors);

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 2400);
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          ...mockModeOverrides(),
          authRepositoryProvider.overrideWithValue(authRepo),
          secureStorageProvider.overrideWithValue(secureStorage),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: createShadiRouter(
              initialLocation: RoutePaths.customerHome,
            ),
          ),
        ),
      );
      // The muhurat ticker animates every second: pump, never settle.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      FlutterError.onError = previous;
      return errors;
    }

    for (final width in widths) {
      testWidgets('the whole Home feed lays out at ${width.toInt()}dp', (
        tester,
      ) async {
        final errors = await pumpHome(tester, width);
        expect(errors, isEmpty, reason: errors.join('\n\n'));

        // The critical surfaces are all present…
        expect(find.byType(CustomerHomeScreen), findsOneWidget);
        expect(find.byType(RouteBookingPanel), findsOneWidget);
        expect(find.byType(ShadiMuhuratCountdownTicker), findsOneWidget);
        expect(find.byType(ShadiUrgentDispatchCard), findsOneWidget);

        // …and the primary action is genuinely reachable: the tap navigates.
        final cta = find.text('Find Cars');
        expect(cta, findsOneWidget);
        expect(tester.getSize(cta).width, lessThanOrEqualTo(width));
        await tester.tap(cta);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(find.byType(SearchResultsScreen), findsOneWidget);

        // Nothing overflowed on the way through either.
        expect(errors, isEmpty, reason: errors.join('\n\n'));
      });
    }

    testWidgets('the Home feed holds at 1.3x text scale on a 360dp phone', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final errors = await pumpHome(tester, 360);
      expect(errors, isEmpty, reason: errors.join('\n\n'));
      expect(find.byType(RouteBookingPanel), findsOneWidget);
      expect(find.text('Find Cars'), findsOneWidget);
    });
  });
}
