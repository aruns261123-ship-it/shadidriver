import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/bookings/data/dto/submit_booking_dto.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/features/bookings/domain/entities/search_handoff.dart';
import 'package:shadidriver/features/home/presentation/widgets/route_booking_panel.dart';
import 'package:shadidriver/features/search/domain/entities/search_query.dart';
import 'package:shadidriver/features/search/domain/entities/search_sort.dart';
import 'package:shadidriver/features/search/domain/entities/trip_type.dart';
import 'package:shadidriver/features/vehicles/data/vehicle_api_repository.dart';

/// Dio interceptor that short-circuits every request, recording it and
/// answering with an empty list envelope. Lets tests assert the REAL query
/// parameters the repository puts on the wire.
class _RecordingInterceptor extends Interceptor {
  static Map<String, dynamic>? lastQuery;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    lastQuery = options.queryParameters;
    handler.resolve(
      Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 200,
        data: const {
          'success': true,
          'data': {'items': [], 'meta': {'page': 1, 'limit': 50, 'total_records': 0, 'has_more': false}},
        },
      ),
    );
  }
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient()
      : super(
          config: EnvironmentConfig.development(),
          logger: _SilentLogger(),
          secureStorage: _NoStorage(),
          dio: Dio()..interceptors.add(_RecordingInterceptor()),
        );
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

class _NoStorage implements SecureStorageService {
  final _map = <String, String>{};
  @override
  Future<bool> containsKey(String key) async => _map.containsKey(key);
  @override
  Future<void> delete(String key) async => _map.remove(key);
  @override
  Future<void> deleteAll() async => _map.clear();
  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> write(String key, String value) async => _map[key] = value;
}

/// Regression: the One Way / Both Way selection must be PERSISTED into the
/// actual API request (search query param), the quote, and the booking
/// payload — not merely live as UI state.
void main() {
  group('TripType wire mapping', () {
    test('panel selection maps onto canonical domain values', () {
      expect(TripDirection.oneWay.wire, TripType.oneWay);
      expect(TripDirection.bothWay.wire, TripType.roundTrip);
      expect(TripType.oneWay.wire, 'ONE_WAY');
      expect(TripType.roundTrip.wire, 'ROUND_TRIP');
      expect(TripType.roundTrip.label, 'Both Way');
    });

    test('server payloads parse back to the same direction', () {
      expect(TripType.fromWire('ROUND_TRIP'), TripType.roundTrip);
      expect(TripType.fromWire('ONE_WAY'), TripType.oneWay);
      expect(TripType.fromWire(null), TripType.oneWay);
    });
  });

  group('search query → ACTUAL API request', () {
    test('searchVehicles sends the selected trip type as a real query param', () async {
      final repo = VehicleApiRepository(_RecordingApiClient());
      await repo.searchVehicles(
        query: const VehicleSearchQuery(
          pickupLocation: 'Delhi NCR',
          tripType: TripType.roundTrip,
        ),
        sort: SearchSort.recommended,
      );
      expect(_RecordingInterceptor.lastQuery?['tripType'], 'ROUND_TRIP');
      expect(repo.lastSearchTripTypeParam, 'ROUND_TRIP');
    });

    test('One Way is sent explicitly as ONE_WAY', () async {
      final repo = VehicleApiRepository(_RecordingApiClient());
      await repo.searchVehicles(
        query: const VehicleSearchQuery(pickupLocation: 'Delhi NCR'),
        sort: SearchSort.recommended,
      );
      expect(_RecordingInterceptor.lastQuery?['tripType'], 'ONE_WAY');
    });
  });

  group('search → handoff → draft → booking payload', () {
    test('handoff carries the trip type', () {
      const handoff = SearchHandoff(
        pickupLocation: 'Delhi NCR',
        destination: 'The Grand Imperial, Agra',
        tripType: TripType.roundTrip,
      );
      expect(handoff.hasAny, isTrue);
      expect(handoff.tripType, TripType.roundTrip);
    });

    test('draft holds the direction and the submission request inherits it', () {
      final draft = BookingDraft.initial(
        vehicleId: 'veh-1',
        vehicleName: 'Toyota Innova Crysta',
        vehicleClass: 'EXECUTIVE_MPV',
        basePricePaise: 250000,
        estimatedTotalPaise: 250000,
        advanceTokenPaise: 62500,
        tripType: TripType.roundTrip,
      );
      expect(draft.tripType, TripType.roundTrip);

      final request = BookingSubmissionRequest.fromDraft(
        draft,
        idempotencyKey: 'idem-trip-0001',
      );
      expect(request.tripType, TripType.roundTrip);
    });

    test('SubmitBookingDto serializes the canonical tripType onto the wire', () {
      final dto = SubmitBookingDto.fromDomain(
        BookingSubmissionRequest.fromDraft(
          BookingDraft.initial(
            vehicleId: 'veh-1',
            vehicleName: 'Toyota Innova Crysta',
            vehicleClass: 'EXECUTIVE_MPV',
            basePricePaise: 250000,
            estimatedTotalPaise: 250000,
            advanceTokenPaise: 62500,
          ).copyWith(tripType: TripType.roundTrip),
          idempotencyKey: 'idem-trip-0002',
        ),
        serviceCategoryId: 'SVC_BARAAT',
      );
      final json = dto.toJson();
      expect(json['tripType'], 'ROUND_TRIP');
      expect(SubmitBookingDto.contractFields, contains('tripType'));
    });
  });
}
