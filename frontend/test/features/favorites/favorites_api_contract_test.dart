import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/config/flavor.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/favorites/data/favorites_api_repository.dart';

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

class _CapturingInterceptor extends Interceptor {
  RequestOptions? lastRequest;
  int requestCount = 0;
  final Map<String, dynamic> body;
  final int? errorStatus;

  _CapturingInterceptor(this.body, {this.errorStatus});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    lastRequest = options;
    requestCount++;
    if (errorStatus != null) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: errorStatus,
            data: body,
          ),
        ),
      );
      return;
    }
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

const _vehicleId = '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e';

Map<String, dynamic> body({
  List<String> vehicleIds = const [_vehicleId],
  int total = 1,
  int unavailable = 0,
  List<String> ignored = const [],
  bool includeItems = true,
}) => {
  'success': true,
  'data': {
    'items': includeItems
        ? [
            {
              'id': _vehicleId,
              'vehicle_type_id': 'VT_THAR',
              'fleet_code': 'SD-VH-0001',
              'make': 'Mahindra',
              'model': 'Thar',
              'display_name': 'Mahindra Thar',
              'year': 2023,
              'vehicle_class': 'PREMIUM_SUV',
              'seating_capacity': 5,
              'city': 'Delhi NCR',
              'image_url': null,
              'amenities': ['AC'],
              'verification_status': 'APPROVED',
              'is_available': true,
              'has_verified_chauffeur': true,
              'rating': 4.5,
              'review_count': 3,
              'price_indicator_paise': '300000',
            },
          ]
        : <Map<String, dynamic>>[],
    'vehicle_ids': vehicleIds,
    'total': total,
    'unavailable_count': unavailable,
    'ignored_vehicle_ids': ignored,
  },
};

void main() {
  late _CapturingInterceptor interceptor;

  FavoritesApiRepository buildRepo(
    Map<String, dynamic> responseBody, {
    int? errorStatus,
  }) {
    interceptor = _CapturingInterceptor(responseBody, errorStatus: errorStatus);
    return FavoritesApiRepository(
      ApiClient(
        config: _config,
        logger: _SilentLogger(),
        secureStorage: _InMemoryStorage(),
        dio: Dio()..interceptors.add(interceptor),
      ),
    );
  }

  group('favourites endpoints', () {
    test('list hits GET /api/v1/favorites', () async {
      await buildRepo(body()).list();
      expect(interceptor.lastRequest!.method, 'GET');
      expect(interceptor.lastRequest!.path, '/api/v1/favorites');
    });

    test('save hits POST /api/v1/favorites/:vehicleId with no body', () async {
      await buildRepo(body()).add(_vehicleId);
      final request = interceptor.lastRequest!;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/favorites/$_vehicleId');
      // Identity comes from the bearer token only.
      expect(request.data, isNull);
    });

    test('unsave hits DELETE /api/v1/favorites/:vehicleId', () async {
      await buildRepo(body()).remove(_vehicleId);
      final request = interceptor.lastRequest!;
      expect(request.method, 'DELETE');
      expect(request.path, '/api/v1/favorites/$_vehicleId');
    });

    test('merge posts the guest shortlist as camelCase vehicleIds', () async {
      await buildRepo(
        body(ignored: ['not-a-uuid']),
      ).merge([_vehicleId, 'not-a-uuid']);

      final request = interceptor.lastRequest!;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/favorites/merge');
      final sent = request.data as Map<String, dynamic>;
      expect(sent.keys, ['vehicleIds']);
      expect(sent['vehicleIds'], [_vehicleId, 'not-a-uuid']);
    });

    test('never sends a customer id from the client', () async {
      await buildRepo(body()).merge([_vehicleId]);
      final sent = (interceptor.lastRequest!.data as Map<String, dynamic>);
      expect(sent.containsKey('customerId'), isFalse);
      expect(sent.containsKey('customer_id'), isFalse);
    });
  });

  group('favourites response mapping', () {
    test('maps the public vehicle payload and the saved id set', () async {
      final result = await buildRepo(body()).list();
      final view = result.dataOrNull!;

      expect(view.vehicleIds, {_vehicleId});
      expect(view.vehicles.single.make, 'Mahindra');
      expect(view.vehicles.single.hasVerifiedChauffeur, isTrue);
      expect(view.vehicles.single.reviewCount, 3);
      expect(view.total, 1);
    });

    test('never surfaces chauffeur identity even if a payload carried it',
        () async {
      final payload = body();
      final item =
          (payload['data'] as Map<String, dynamic>)['items'] as List<dynamic>;
      (item.first as Map<String, dynamic>)['chauffeur'] = {
        'full_name': 'Ramesh Chauhan',
        'phone': '+919810000009',
      };
      final result = await buildRepo(payload).list();
      expect(result.dataOrNull!.vehicles, isNotEmpty);
      // The shared public mapper simply never reads those fields.
      expect(
        '${result.dataOrNull!.vehicles.single}',
        isNot(contains('Ramesh')),
      );
    });

    test('reports saved vehicles that are no longer available', () async {
      final result = await buildRepo(
        body(vehicleIds: [_vehicleId], includeItems: false, total: 3, unavailable: 3),
      ).list();
      final view = result.dataOrNull!;

      expect(view.vehicleIds, {_vehicleId});
      expect(view.vehicles, isEmpty);
      expect(view.unavailableCount, 3);
    });

    test('reports guest shortlist entries the server could not import', () async {
      final result = await buildRepo(
        body(ignored: ['stale-id']),
      ).merge([_vehicleId, 'stale-id']);
      expect(result.dataOrNull!.ignoredVehicleIds, ['stale-id']);
    });

    test('a 403 (not a customer account) becomes a typed failure', () async {
      final failing = buildRepo(
        {
          'success': false,
          'error': {'code': 'ROLE_FORBIDDEN', 'message': 'Forbidden.'},
        },
        errorStatus: 403,
      );

      final result = await failing.list();
      expect(result.isFailure, isTrue);
    });
  });
}
