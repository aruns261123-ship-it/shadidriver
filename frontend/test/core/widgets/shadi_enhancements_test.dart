import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/widgets/shadi_ceremonial_route_map.dart';
import 'package:shadidriver/core/widgets/shadi_muhurat_countdown_ticker.dart';
import 'package:shadidriver/core/widgets/shadi_offline_banner.dart';

void main() {
  group('ShadiCeremonialRouteMap Tests', () {
    testWidgets('renders route coordinates and destination text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShadiCeremonialRouteMap(
              pickupLocation: 'The Oberoi Grand',
              destinationLocation: 'ITC Sonar Royal Banquet',
              distance: '18.4 km',
              duration: '42 mins',
            ),
          ),
        ),
      );

      expect(find.text('The Oberoi Grand'), findsOneWidget);
      expect(find.text('ITC Sonar Royal Banquet'), findsOneWidget);
      expect(find.text('42 mins • 18.4 km'), findsOneWidget);
      expect(find.text('LIVE GPS ROUTE'), findsOneWidget);
    });

    testWidgets('renders non-live itinerary label when isLive is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShadiCeremonialRouteMap(
              pickupLocation: 'Taj Bengal',
              destinationLocation: 'Eco Park Lake',
              isLive: false,
            ),
          ),
        ),
      );

      expect(find.text('CEREMONIAL ITINERARY'), findsOneWidget);
    });
  });

  group('ShadiMuhuratCountdownTicker Tests', () {
    testWidgets('renders countdown boxes and ceremony header', (tester) async {
      final target = DateTime.now().add(
        const Duration(hours: 2, minutes: 30, seconds: 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShadiMuhuratCountdownTicker(
              targetTime: target,
              ceremonyName: 'Varmala & Pheras',
              venueName: 'The Leela Palace',
            ),
          ),
        ),
      );

      expect(find.text('VARMALA & PHERAS'), findsOneWidget);
      expect(find.text('The Leela Palace'), findsOneWidget);
      expect(find.text('HOURS'), findsOneWidget);
      expect(find.text('MINS'), findsOneWidget);
      expect(find.text('SECS'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('ShadiOfflineBanner Tests', () {
    testWidgets('displays offline resilience message and can be dismissed', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShadiOfflineBanner(message: 'Offline Sync Active'),
          ),
        ),
      );

      expect(find.text('Offline Sync Active'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);

      // Tap dismiss icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('Offline Sync Active'), findsNothing);
    });
  });
}
