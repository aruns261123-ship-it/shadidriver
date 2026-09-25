import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/config/flavor.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/vehicles/data/vehicle_api_repository.dart';

class _InMemoryStorage implements SecureStorageService {
  final Map<String, String> _data = {};
  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);
  @override
  Future<void> delete(String key) async => _data.remove(key);
  @override
  Future<void> deleteAll() async => _data.clear();
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

class _SilentLogger implements AppLogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {}
}

class _StubInterceptor extends Interceptor {
  final Map<String, dynamic> body;
  _StubInterceptor(this.body);
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.resolve(
      Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 200,
        data: body,
      ),
    );
  }
}

const _config = EnvironmentConfig(
  flavor: AppFlavor.development,
  appName: 'ShadiDriver Test',
  apiBaseUrl: 'http://localhost:3000',
  wsBaseUrl: 'ws://localhost:3000',
  useMockData: false,
);

/// The canonical public vehicle detail payload produced by
/// `backend/src/vehicles/dto/public-vehicle.dto.ts`.
Map<String, dynamic> canonicalDetail({
  Map<String, dynamic> overrides = const {},
}) => {
  'success': true,
  'data': {
    'id': '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e',
    'vehicle_type_id': 'VT_INNOVA_CRYSTA',
    'fleet_code': 'SD-VH-0001',
    'make': 'Toyota',
    'model': 'Innova Crysta',
    'display_name': 'Toyota Innova Crysta',
    'year': 2023,
    'vehicle_class': 'EXECUTIVE_MPV',
    'seating_capacity': 7,
    'city': 'Delhi NCR',
    'image_url': 'https://cdn.example/hero.jpg',
    'amenities': ['AC', 'Sunroof'],
    'verification_status': 'APPROVED',
    'is_available': true,
    'has_verified_chauffeur': true,
    'rating': 4.5,
    'review_count': 12,
    'price_indicator_paise': '2500000',
    'color': 'Pearl White',
    'fuel_type': 'DIESEL',
    'air_conditioning': 'DUAL_CLIMATE_CONTROL',
    'is_vintage': false,
    'service_areas': ['Delhi NCR'],
    'photos': ['https://cdn.example/1.jpg'],
    'documents_summary': {'total': 6, 'verified': 5, 'expiring_soon': 1},
    'suitable_ceremonies': ['Guest Transport', 'Airport VIP'],
    ...overrides,
  },
};

void main() {
  VehicleApiRepository buildRepo(Map<String, dynamic> body) {
    final dio = Dio()..interceptors.add(_StubInterceptor(body));
    return VehicleApiRepository(
      ApiClient(
        config: _config,
        logger: _SilentLogger(),
        secureStorage: _InMemoryStorage(),
        dio: dio,
      ),
    );
  }

  group('public vehicle detail mapping', () {
    test('reads trust from the boolean flag the backend owns', () async {
      // No chauffeur object anywhere — the trust signal is explicit.
      final result = await buildRepo(canonicalDetail()).getVehicleDetails(
        '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e',
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.hasVerifiedChauffeur, isTrue);
    });

    test('does NOT derive trust from leaked chauffeur identity', () async {
      // A payload that still carried a chauffeur object must not make the
      // client infer trust: only `has_verified_chauffeur` counts.
      final payload = canonicalDetail(
        overrides: {
          'has_verified_chauffeur': false,
          'chauffeur': {
            'id': 'driver-user-1',
            'full_name': 'Ramesh Chauhan',
            'avatar_url': 'https://cdn.example/face.jpg',
          },
          'chauffeur_name': 'Ramesh Chauhan',
          'registration_number': 'DL01AB1234',
        },
      );
      final result = await buildRepo(payload).getVehicleDetails(
        '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e',
      );

      final details = result.dataOrNull!;
      expect(details.hasVerifiedChauffeur, isFalse);
      // Nothing sourced from the leaked identity fields reaches the UI model.
      expect(
        '${details.make}${details.model}${details.suitabilityInfo}${details.amenities}',
        isNot(contains('Ramesh')),
      );
      expect(details.galleryUrls, isNot(contains('face.jpg')));
    });

    test('uses the fleet reference, never the registration plate', () async {
      final result = await buildRepo(canonicalDetail()).getVehicleDetails(
        '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e',
      );
      expect(result.dataOrNull!.id, isNotEmpty);
    });

    test('maps the server price indicator instead of inventing a price',
        () async {
      final result = await buildRepo(canonicalDetail()).getVehicleDetails(
        '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e',
      );
      expect(result.dataOrNull!.pricing.basePriceCents, 2500000);
      expect(result.dataOrNull!.pricing.isUnavailable, isFalse);
    });

    test('a missing tariff reads as unavailable, not as Rs 0', () async {
      final payload = canonicalDetail()..['data'].remove('price_indicator_paise');
      final result = await buildRepo(payload).getVehicleDetails(
        '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e',
      );
      expect(result.dataOrNull!.pricing.isUnavailable, isTrue);
    });

    test('suitability comes from the backend, not from the vehicle class',
        () async {
      final result = await buildRepo(canonicalDetail()).getVehicleDetails(
        '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e',
      );
      expect(result.dataOrNull!.suitableCeremonies, [
        'Guest Transport',
        'Airport VIP',
      ]);
    });

    test('does not fabricate priced add-ons the backend never sent', () async {
      final result = await buildRepo(canonicalDetail()).getVehicleDetails(
        '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e',
      );
      // Client-side priced packages were removed: no invented Rs 3,500 floral
      // decoration may appear on a vehicle the server priced without add-ons.
      expect(result.dataOrNull!.ceremonialAddons, isEmpty);
    });
  });

  group('public vehicle list mapping', () {
    Map<String, dynamic> listBody(Map<String, dynamic> item) => {
      'success': true,
      'data': {
        'items': [item],
        'meta': {'page': 1, 'limit': 20, 'total_records': 1, 'has_more': false},
      },
    };

    test('carries the server rating and review count, not hardcoded values',
        () async {
      final result = await buildRepo(listBody(canonicalDetail()['data']))
          .getFeaturedVehicles();

      final summary = result.dataOrNull!.single;
      expect(summary.rating, 4.5);
      expect(summary.reviewCount, 12);
    });

    test('leaves distance and transmission unknown rather than inventing them',
        () async {
      final result = await buildRepo(listBody(canonicalDetail()['data']))
          .getFeaturedVehicles();

      final summary = result.dataOrNull!.single;
      expect(summary.distanceKm, isNull);
      expect(summary.transmission, isNull);
    });

    test('an absent trust flag reads as false, never as true', () async {
      final item = Map<String, dynamic>.from(canonicalDetail()['data'] as Map)
        ..remove('has_verified_chauffeur');
      final result = await buildRepo(listBody(item)).getFeaturedVehicles();

      expect(result.dataOrNull!.single.hasVerifiedChauffeur, isFalse);
    });
  });
}
