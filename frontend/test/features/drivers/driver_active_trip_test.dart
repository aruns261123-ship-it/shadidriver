import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_trip_stage.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_active_trip_controller.dart';
import 'package:shadidriver/features/drivers/presentation/driver_active_trip_screen.dart';

import '../../helpers/mock_env.dart';

void main() {
  group('DriverActiveTripController Lifecycle Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: mockModeOverrides());
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is assigned', () {
      final state = container.read(
        driverActiveTripControllerProvider('test_b1'),
      );
      expect(state.trip.stage, equals(DriverTripStage.assigned));
      expect(state.trip.bookingReference, equals('SD-2026-0100'));
      expect(state.trip.ceremonyType, equals('Baraat'));
      expect(state.isUpdating, isFalse);
    });

    test('startEnRoute transitions to enRouteToPickup', () async {
      final controller = container.read(
        driverActiveTripControllerProvider('test_b1').notifier,
      );
      await controller.startEnRoute();
      final state = container.read(
        driverActiveTripControllerProvider('test_b1'),
      );
      expect(state.trip.stage, equals(DriverTripStage.enRouteToPickup));
    });

    test('markArrived transitions to arrivedAtPickup', () async {
      final controller = container.read(
        driverActiveTripControllerProvider('test_b1').notifier,
      );
      await controller.startEnRoute();
      await controller.markArrived();
      final state = container.read(
        driverActiveTripControllerProvider('test_b1'),
      );
      expect(state.trip.stage, equals(DriverTripStage.arrivedAtPickup));
    });

    test('startCeremonyService rejects invalid OTP', () async {
      final controller = container.read(
        driverActiveTripControllerProvider('test_b1').notifier,
      );
      await controller.startEnRoute();
      await controller.markArrived();

      final success = await controller.startCeremonyService(
        otp: '9999',
        attireConfirmed: true,
      );

      expect(success, isFalse);
      final state = container.read(
        driverActiveTripControllerProvider('test_b1'),
      );
      expect(state.trip.stage, equals(DriverTripStage.arrivedAtPickup));
      expect(state.errorMessage, contains('Invalid Host Start OTP'));
    });

    test('startCeremonyService requires attire confirmation', () async {
      final controller = container.read(
        driverActiveTripControllerProvider('test_b1').notifier,
      );
      await controller.startEnRoute();
      await controller.markArrived();

      final success = await controller.startCeremonyService(
        otp: '482913',
        attireConfirmed: false,
      );

      expect(success, isFalse);
      final state = container.read(
        driverActiveTripControllerProvider('test_b1'),
      );
      expect(state.errorMessage, contains('attire verification is required'));
    });

    test('startCeremonyService succeeds with valid OTP and attire', () async {
      final controller = container.read(
        driverActiveTripControllerProvider('test_b1').notifier,
      );
      await controller.startEnRoute();
      await controller.markArrived();

      final success = await controller.startCeremonyService(
        otp: '482913',
        attireConfirmed: true,
      );

      expect(success, isTrue);
      final state = container.read(
        driverActiveTripControllerProvider('test_b1'),
      );
      expect(state.trip.stage, equals(DriverTripStage.ceremonyInProgress));
      expect(state.trip.tripStartedAt, isNotNull);
      expect(state.trip.ceremonialAttireConfirmed, isTrue);
    });

    test('completeService transitions to completed', () async {
      final controller = container.read(
        driverActiveTripControllerProvider('test_b1').notifier,
      );
      await controller.startEnRoute();
      await controller.markArrived();
      await controller.startCeremonyService(otp: '482913', attireConfirmed: true);
      await controller.completeService();

      final state = container.read(
        driverActiveTripControllerProvider('test_b1'),
      );
      expect(state.trip.stage, equals(DriverTripStage.completed));
      expect(state.trip.tripCompletedAt, isNotNull);
    });
  });

  group('DriverActiveTripScreen Widget Tests', () {
    testWidgets('renders progress stepper, banners, and action button', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: mockModeOverrides(),
          child: const MaterialApp(
            home: DriverActiveTripScreen(bookingId: 'bk_mock_req_1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // App bar
      expect(find.textContaining('Trip Console'), findsOneWidget);
      expect(find.textContaining('SD-2026-0100'), findsOneWidget);
      expect(find.textContaining('Baraat Ceremony'), findsOneWidget);

      // Stepper
      expect(find.text('En Route'), findsOneWidget);
      expect(find.text('Arrived'), findsOneWidget);
      expect(find.text('Ceremony'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Route & Host
      expect(find.text('The Oberoi Hotel, New Delhi'), findsWidgets);
      expect(find.textContaining('Grand Imperial Banquets'), findsWidgets);
      final hostFinder = find.text('Vikram Malhotra');
      await tester.scrollUntilVisible(hostFinder, 150);
      expect(hostFinder, findsOneWidget);

      // Initial Action Button
      final startBtn = find.text('Start Journey to Pickup');
      await tester.scrollUntilVisible(startBtn, 200);
      expect(startBtn, findsOneWidget);

      // Tap 'Start Journey to Pickup'
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      // Next stage button
      final arrivedBtn = find.text('Arrived at Pickup / Venue');
      await tester.scrollUntilVisible(arrivedBtn, 200);
      expect(arrivedBtn, findsOneWidget);
    });
  });
}
