import 'package:dio/dio.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/config/flavor.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/bookings/data/booking_api_repository.dart';
import 'package:shadidriver/features/vehicles/data/vehicle_api_repository.dart';

import 'privacy_sentinels.dart';

/// Feeds HOSTILE payloads through the REAL API repositories.
///
/// The backend is supposed to strip private fields before they reach the wire,
/// but a client that trusts that contract has no defense when it regresses.
/// These payloads deliberately include driver identity, partner identity,
/// registration plates, internal notes and internal keys so the mappers'
/// filtering behaviour is pinned by tests rather than assumed.
class HostileApiHarness {
  static const _config = EnvironmentConfig(
    flavor: AppFlavor.development,
    appName: 'ShadiDriver Privacy Harness',
    apiBaseUrl: 'http://localhost:3000',
    wsBaseUrl: 'ws://localhost:3000',
    useMockData: false,
  );

  /// A booking repository whose every response is [payload].
  static BookingApiRepository bookingRepository(Map<String, dynamic> payload) {
    final dio = Dio()..interceptors.add(_StaticInterceptor(payload));
    return BookingApiRepository(
      ApiClient(
        config: _config,
        logger: _SilentLogger(),
        secureStorage: _InMemoryStorage(),
        dio: dio,
      ),
    );
  }

  /// A vehicle repository whose every response is [payload].
  static VehicleApiRepository vehicleRepository(
    Map<String, dynamic> payload,
  ) {
    final dio = Dio()..interceptors.add(_StaticInterceptor(payload));
    return VehicleApiRepository(
      ApiClient(
        config: _config,
        logger: _SilentLogger(),
        secureStorage: _InMemoryStorage(),
        dio: dio,
      ),
    );
  }
}

/// Answers every request with one fixed body.
class _StaticInterceptor extends Interceptor {
  _StaticInterceptor(this.body);
  final Map<String, dynamic> body;

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

// ----------------------------------------------------------- hostile payloads

/// The private/legacy keys a customer payload must never act on, at every level.
Map<String, Object?> hostilePrivateBlock() => {
  'driver': {
    'id': PrivacySentinels.driverId,
    'user': {
      'full_name': PrivacySentinels.driverName,
      'fullName': PrivacySentinels.driverName,
      'phone_number': PrivacySentinels.driverPhone,
      'phoneNumber': PrivacySentinels.driverPhone,
      'email': PrivacySentinels.driverEmail,
      'address': PrivacySentinels.driverAddress,
    },
  },
  'driver_id': PrivacySentinels.driverId,
  'driverFk': PrivacySentinels.driverId,
  'chauffeur': {'name': PrivacySentinels.driverName},
  'chauffeur_name': PrivacySentinels.driverName,
  'chauffeur_phone': PrivacySentinels.driverPhone,
  'assigned_chauffeur': {
    'id': PrivacySentinels.driverId,
    'name': PrivacySentinels.driverName,
    'phone': PrivacySentinels.driverPhone,
  },
  'owner_name': PrivacySentinels.partnerName,
  'fleet_owner': PrivacySentinels.partnerName,
  'partner': {'name': PrivacySentinels.partnerName},
  'registration_number': PrivacySentinels.registrationPlate,
  'internal_notes': PrivacySentinels.internalNote,
  'idempotency_key': PrivacySentinels.internalKey,
  'start_otp_hash': 'f' * 64,
};

/// A customer VIEW booking payload with the hostile block merged in.
Map<String, dynamic> hostileCustomerBookingPayload() => {
  'success': true,
  'data': {
    'id': 'bk_hostile_1',
    'reference_code': 'SD-2026-0199',
    'status': 'CONFIRMED',
    'submitted_at': '2026-09-30T06:00:00.000Z',
    'trip_type': 'ONE_WAY',
    'ceremony_type': 'Baraat',
    'city': 'Delhi NCR',
    'vehicle_name': 'BMW 5 Series SD-DEL-00042',
    'pickup_address': 'The Oberoi, New Delhi',
    'destination_address': 'The Leela Palace, New Delhi',
    'service_start_time': '2026-11-20T10:30:00.000Z',
    'service_end_time': '2026-11-20T18:30:00.000Z',
    'passenger_count': 4,
    'estimated_total_paise': '3500000',
    'advance_token_paise': '700000',
    'is_advance_paid': true,
    // The contract says `driver: null` for a customer view; this payload
    // deliberately violates it to prove the client does not act on it.
    'chauffeur_verification': 'Vehicle and chauffeur verified by ShadiDriver',
    ...hostilePrivateBlock(),
  },
};

/// A customer VIEW group payload with the hostile block merged into each
/// assignment (and into the parent).
Map<String, dynamic> hostileCustomerGroupPayload() => {
  'success': true,
  'data': {
    'id': 'grp_hostile_1',
    'reference_code': 'SD-GRP-2026-000199',
    'ceremony_type': 'Baraat',
    'city': 'Delhi NCR',
    'pickup_address': 'Sector 15, Gurugram',
    'destination_address': 'The Leela Palace, New Delhi',
    'service_start_time': '2026-11-20T10:00:00.000Z',
    'service_end_time': '2026-11-20T22:00:00.000Z',
    'passenger_count': 12,
    'status': 'CUSTOMER_CONFIRMATION_PENDING',
    'version': 3,
    'trip_type': 'ONE_WAY',
    'estimated_total_paise': '11250000',
    'advance_token_paise': '2812500',
    'quote_pending': false,
    'requirements': ['Wedding decoration'],
    'communication_preference': 'WHATSAPP',
    'requested_fleet': [
      {'vehicleTypeId': 'VT_INNOVA_CRYSTA', 'quantity': 2},
    ],
    'created_at': '2026-09-30T06:00:00.000Z',
    ...hostilePrivateBlock(),
    'assignments': [
      {
        'id': 'asg_hostile_1',
        'sequence_number': 1,
        'requested_model': 'Toyota Innova Crysta',
        'vehicle': {
          'id': 'veh_hostile_1',
          'fleet_code': 'SD-DEL-00001',
          'display_name': 'Toyota Innova Crysta',
          'registration_number': PrivacySentinels.registrationPlate,
        },
        'chauffeur_assigned': true,
        'service_state': 'BEING_PREPARED',
        'estimated_total_paise': '5625000',
        'advance_token_paise': '1406250',
        ...hostilePrivateBlock(),
      },
    ],
  },
};

/// A public vehicle payload with the hostile block merged in.
Map<String, dynamic> hostileVehiclePayload() => {
  'success': true,
  'data': {
    'id': 'veh_hostile_1',
    'vehicle_type_id': 'VT_BMW5',
    'fleet_code': 'SD-DEL-00042',
    'make': 'BMW',
    'model': '5 Series',
    'year': 2024,
    'vehicle_class': 'LUXURY_SEDAN',
    'seating_capacity': 4,
    'verification_status': 'APPROVED',
    'has_verified_chauffeur': true,
    'amenities': ['Dual AC'],
    'photos': ['/media/vehicles/bmw.png'],
    'fuel_type': 'Petrol',
    'service_areas': ['Delhi NCR'],
    'price_indicator_paise': '2188',
    'is_available': true,
    ...hostilePrivateBlock(),
  },
};
