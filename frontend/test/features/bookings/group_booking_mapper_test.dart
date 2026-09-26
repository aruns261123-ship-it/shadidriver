import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/config/flavor.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/bookings/data/booking_api_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/bookings/domain/entities/group_booking_submission_request.dart';
import 'package:shadidriver/features/bookings/domain/entities/customer_fleet_intent.dart';

/// These tests pin the mapper to the payload the backend ACTUALLY returns.
/// It previously read camelCase mock fields (`referenceCode`,
/// `estimatedTotalPaise`) while the API sends snake_case, so the app showed an
/// empty reference and ₹0 for a real booking, and it expected a
/// `registration_number`/`chauffeur.full_name` that a customer payload must
/// never contain.

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
  RequestOptions? lastRequest;
  final Map<String, dynamic> body;

  _StubInterceptor(this.body);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    lastRequest = options;
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

const _groupId = '74553441-ab92-4f14-aa09-ed80ad993f06';

/// A faithful copy of the real customer payload (verified against the running
/// backend), including the fields the old mapper got wrong.
Map<String, dynamic> payload({
  String status = 'CUSTOMER_CONFIRMATION_PENDING',
  Object? estimatedTotalPaise = '11317500',
  Object? advanceTokenPaise = '2829375',
  bool chauffeurAssigned = true,
}) =>
    {
      'success': true,
      'data': {
        'id': _groupId,
        'reference_code': 'SD-GRP-2026-000123',
        'ceremony_type': 'Baraat',
        'city': 'Delhi NCR',
        'pickup_address': 'Sector 15, Gurugram',
        'destination_address': 'The Leela Palace, New Delhi',
        'service_start_time': '2027-02-13T04:00:00.000Z',
        'service_end_time': '2027-02-13T16:00:00.000Z',
        'passenger_count': 7,
        'status': status,
        'version': 4,
        'estimated_total_paise': estimatedTotalPaise,
        'advance_token_paise': advanceTokenPaise,
        'quote_pending': estimatedTotalPaise == null,
        'requirements': ['Wedding decoration', 'Child seat'],
        'communication_preference': 'WHATSAPP',
        'requested_fleet': [
          {'vehicleTypeId': 'VT_INNOVA_CRYSTA', 'quantity': 2},
        ],
        'assignments': [
          {
            'id': 'cdb2d18f-7e03-4349-ba27-773899a581e8',
            'sequence_number': 1,
            'requested_model': 'Toyota Innova Crysta',
            'vehicle': {
              'id': 'b3831825-d377-40b8-866d-2135b78a6eea',
              'fleet_code': 'SD-VH-0001',
              'display_name': 'Toyota Innova Crysta',
            },
            'chauffeur_assigned': chauffeurAssigned,
            'service_state': 'BEING_PREPARED',
            'estimated_total_paise': '5625000',
            'advance_token_paise': '1406250',
          },
          {
            'id': 'edae86fc-cfb9-4674-90de-3e1e7654e25a',
            'sequence_number': 2,
            'requested_model': 'Toyota Innova Crysta',
            'vehicle': {
              'id': '6e9815fe-4b9d-4c92-a905-08ac83447554',
              'fleet_code': 'SD-VH-0002',
              'display_name': 'Toyota Innova Crysta',
            },
            'chauffeur_assigned': chauffeurAssigned,
            'service_state': 'BEING_PREPARED',
            'estimated_total_paise': '5625000',
            'advance_token_paise': '1406250',
          },
        ],
      },
    };

void main() {
  late _StubInterceptor interceptor;

  BookingApiRepository buildRepo(Map<String, dynamic> responseBody) {
    interceptor = _StubInterceptor(responseBody);
    return BookingApiRepository(
      ApiClient(
        config: _config,
        logger: _SilentLogger(),
        secureStorage: _InMemoryStorage(),
        dio: Dio()..interceptors.add(interceptor),
      ),
    );
  }

  group('group booking detail mapping', () {
    test('reads the real snake_case contract, not mock camelCase fields',
        () async {
      final result = await buildRepo(payload()).getGroupBooking(_groupId);
      final group = result.dataOrNull!;

      expect(interceptor.lastRequest!.path, '/api/v1/group-bookings/$_groupId');
      expect(group.bookingReference, 'SD-GRP-2026-000123');
      expect(group.pickupAddress, 'Sector 15, Gurugram');
      expect(group.destinationAddress, 'The Leela Palace, New Delhi');
      expect(group.city, 'Delhi NCR');
      expect(group.ceremonyType, 'Baraat');
      expect(group.totalPassengers, 7);
      expect(group.serviceStartDateTime.year, 2027);
      expect(group.estimatedTotalPaise, 11317500);
      expect(group.advanceTokenPaise, 2829375);
      expect(group.quotePending, isFalse);
      expect(group.requirements, ['Wedding decoration', 'Child seat']);
      expect(group.communicationPreference, 'WHATSAPP');
      expect(group.version, 4);
    });

    test('maps the managed lifecycle states the backend actually sends',
        () async {
      const expected = {
        'REQUESTED': BookingStatus.requested,
        'UNDER_REVIEW': BookingStatus.underReview,
        'VEHICLE_OPTIONS_PREPARED': BookingStatus.vehicleOptionsPrepared,
        'CUSTOMER_CONFIRMATION_PENDING':
            BookingStatus.customerConfirmationPending,
        'CONFIRMED': BookingStatus.confirmed,
        'COMPLETED': BookingStatus.completed,
        'CANCELLED': BookingStatus.cancelled,
        'EXPIRED': BookingStatus.expired,
      };

      for (final entry in expected.entries) {
        final result =
            await buildRepo(payload(status: entry.key)).getGroupBooking(_groupId);
        expect(
          result.dataOrNull!.status,
          entry.value,
          reason: 'wire status ${entry.key}',
        );
      }
    });

    test('an unquoted booking stays "on request" — never ₹0', () async {
      final result = await buildRepo(
        payload(estimatedTotalPaise: null, advanceTokenPaise: null),
      ).getGroupBooking(_groupId);
      final group = result.dataOrNull!;

      expect(group.estimatedTotalPaise, isNull);
      expect(group.advanceTokenPaise, isNull);
      expect(group.quotePending, isTrue);
      expect(group.assignments.every((a) => a.pricePaise != 0), isTrue);
    });

    test('never surfaces chauffeur identity, plates or partner names', () async {
      final group =
          (await buildRepo(payload()).getGroupBooking(_groupId)).dataOrNull!;

      for (final assignment in group.assignments) {
        expect(assignment.chauffeurName, isNull);
        expect(assignment.chauffeurId, isNull);
        expect(assignment.ownerName, isEmpty);
        // Displayed as the model plus its opaque fleet code — never the plate.
        expect(assignment.vehicleName, contains('SD-VH-'));
        expect(assignment.vehicleName, contains('Toyota Innova Crysta'));
        // Chauffeur state arrives as a neutral boolean.
        expect(assignment.chauffeurAssigned, isTrue);
        expect(assignment.status, 'BEING_PREPARED');
      }
    });

    test('reports a not-yet-staffed booking as chauffeur-pending', () async {
      final group =
          (await buildRepo(payload(chauffeurAssigned: false)).getGroupBooking(_groupId))
              .dataOrNull!;
      expect(group.assignments.every((a) => !a.chauffeurAssigned), isTrue);
    });
  });

  group('group booking submission', () {
    test('sends requirements and the confirmation channel', () async {
      await buildRepo({
        'success': true,
        'data': {
          'groupBooking': payload()['data'],
          'idempotentReplay': false,
        },
      }).submitGroupBooking(
        GroupBookingSubmissionRequest(
          fleetIntent: CustomerFleetIntent.mixed(
            passengerCount: 7,
            units: const {'VT_INNOVA_CRYSTA': 2},
          ),
          ceremonyType: 'Baraat',
          serviceStartDateTime: DateTime.utc(2027, 2, 13, 4),
          serviceEndDateTime: DateTime.utc(2027, 2, 13, 16),
          city: 'Delhi NCR',
          pickupAddress: 'Sector 15, Gurugram',
          destinationAddress: 'The Leela Palace, New Delhi',
          primaryContactName: 'Aarav Sharma',
          primaryContactPhone: '+919810000001',
          idempotencyKey: 'idem-key-1234567890',
          requirements: const ['Wedding decoration'],
          communicationPreference: 'WHATSAPP',
        ),
      );

      final request = interceptor.lastRequest!;
      expect(request.path, '/api/v1/group-bookings');
      final body = request.data as Map<String, dynamic>;
      expect(body['requirements'], ['Wedding decoration']);
      expect(body['communicationPreference'], 'WHATSAPP');
      expect(body['fleet'], [
        {'vehicleTypeId': 'VT_INNOVA_CRYSTA', 'quantity': 2},
      ]);
    });
  });
}
