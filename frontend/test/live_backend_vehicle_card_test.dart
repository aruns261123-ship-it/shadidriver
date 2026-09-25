import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/config/flavor.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/home/presentation/view_models/vehicle_card_view_model.dart';
import 'package:shadidriver/features/vehicles/data/vehicle_api_repository.dart';
import 'package:shadidriver/features/vehicles/presentation/widgets/shadi_vehicle_card.dart';

class InMemorySecureStorage implements SecureStorageService {
  final Map<String, String> _storage = {};
  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);
  @override
  Future<void> delete(String key) async => _storage.remove(key);
  @override
  Future<void> deleteAll() async => _storage.clear();
  @override
  Future<String?> read(String key) async => _storage[key];
  @override
  Future<void> write(String key, String value) async => _storage[key] = value;
}

class SilentTestLogger implements AppLogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {}
}

/// Real API → real response → real UI.
///
/// The fleet the backend actually returns (UUID primary key, fleet code, real
/// paise pricing, real chauffeur assignment) is rendered by the real result card
/// at three phone widths, proving the layout survives production data rather
/// than the short demo fixtures.
///
/// Requires a running backend:
///   LIVE_API_BASE_URL=http://localhost:3010 flutter test test/live_backend_vehicle_card_test.dart
void main() {
  final baseUrl =
      Platform.environment['LIVE_API_BASE_URL'] ?? 'http://localhost:3000';

  setUp(() {
    // Widget tests install a mock HttpClient that answers every request with
    // 400. This file exists specifically to render live data, so the mock is
    // removed for the duration of the test.
    HttpOverrides.global = null;
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  testWidgets('the real fleet renders in the real card without overflow', (
    tester,
  ) async {
    final client = ApiClient(
      config: EnvironmentConfig(
        flavor: AppFlavor.development,
        appName: 'ShadiDriver Dev',
        apiBaseUrl: baseUrl,
        wsBaseUrl: baseUrl.replaceFirst('http', 'ws'),
        useMockData: false,
      ),
      logger: SilentTestLogger(),
      secureStorage: InMemorySecureStorage(),
    );
    final vehicleRepo = VehicleApiRepository(client);

    final featured = await tester.runAsync(
      () => vehicleRepo.getFeaturedVehicles(),
    );
    if (featured == null || featured.isFailure) {
      markTestSkipped(
        'No reachable backend at $baseUrl. Start it, then set '
        'LIVE_API_BASE_URL and re-run this file.',
      );
      return;
    }

    final vehicles = featured.dataOrNull!;
    expect(vehicles, isNotEmpty, reason: 'the seeded fleet must not be empty');

    final vehicle = vehicles.first;
    // Real backend rows are keyed by UUID and carry a fleet code.
    expect(vehicle.id.contains('-'), isTrue, reason: 'real id is a UUID');
    expect(vehicle.make.isNotEmpty, isTrue);

    final viewModel = VehicleCardViewModel.fromEntity(vehicle);
    for (final width in <double>[320, 360, 411]) {
      final errors = await _pumpCard(tester, viewModel, width);
      for (final error in errors) {
        debugPrint(error.toString());
      }
      expect(
        errors,
        isEmpty,
        reason: 'the real fleet card must not overflow at ${width}dp',
      );
    }

    expect(viewModel.title.trim(), isNotEmpty);
    expect(viewModel.priceText, startsWith('₹'));
    expect(find.text('View Details'), findsOneWidget);
  });
}

/// Pumps the real card at an exact phone width and returns every layout error
/// Flutter reported while painting it.
Future<List<FlutterErrorDetails>> _pumpCard(
  WidgetTester tester,
  VehicleCardViewModel viewModel,
  double width,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);

  final captured = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = captured.add;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ShadiVehicleCard(viewModel: viewModel, onTap: () {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  FlutterError.onError = previous;
  tester.takeException();
  return captured;
}
