import 'package:dio/dio.dart';
import '../../features/auth/domain/entities/account_status.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../constants/app_constants.dart';
import '../errors/failures.dart';

/// Versioned API path segments shared by all API repositories.
abstract final class ApiPaths {
  static const String v1 = AppConstants.apiV1Prefix;
}

/// Parsed representation of the backend's documented response envelope:
/// `{ success, data, meta }` (meta optional).
class ApiEnvelope {
  final bool success;
  final dynamic data;
  final Map<String, dynamic>? meta;

  const ApiEnvelope({required this.success, this.data, this.meta});

  static ApiEnvelope fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return ApiEnvelope(
        success: json['success'] is bool ? json['success'] as bool : true,
        data: json['data'],
        meta: json['meta'] is Map<String, dynamic>
            ? json['meta'] as Map<String, dynamic>
            : null,
      );
    }
    // Endpoints that return bare payloads (no envelope) still work.
    return ApiEnvelope(success: true, data: json);
  }
}

/// Backend error payload shape:
/// `{ success: false, error: { code, message, details? }, request_id? }`.
({String code, String message}) _extractBackendError(dynamic body) {
  if (body is Map<String, dynamic>) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      return (
        code: (error['code'] as String?) ?? 'UNKNOWN_ERROR',
        message: (error['message'] as String?) ?? 'Request failed.',
      );
    }
    // Fallbacks for legacy shapes.
    final code = body['code'] as String?;
    final message = body['message'] as String?;
    if (code != null || message != null) {
      return (code: code ?? 'UNKNOWN_ERROR', message: message ?? 'Request failed.');
    }
  }
  return (code: 'UNKNOWN_ERROR', message: 'Request failed.');
}

/// Maps Dio exceptions onto the typed [AppFailure] hierarchy.
AppFailure mapDioError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return const NetworkFailure();
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutFailure();
      case DioExceptionType.cancel:
        return const UnknownFailure('Request cancelled.', 'REQUEST_CANCELLED');
      case DioExceptionType.badCertificate:
        return const NetworkFailure('Server certificate could not be verified.');
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        final parsed = _extractBackendError(error.response?.data);
        return switch (status) {
          400 => ValidationFailure(parsed.message, code: parsed.code),
          401 => UnauthorizedFailure(parsed.message, parsed.code),
          403 => ForbiddenFailure(parsed.message, parsed.code),
          404 => NotFoundFailure(parsed.message),
          409 => ConflictFailure(parsed.message),
          422 => ValidationFailure(parsed.message, code: parsed.code),
          _ => ServerFailure(parsed.message, parsed.code, null, status),
        };
      case DioExceptionType.unknown:
      case DioExceptionType.transformTimeout:
        return UnknownFailure(error.message ?? 'Unexpected error occurred.');
    }
  }
  return UnknownFailure(error.toString());
}

// ---------------------------------------------------------------------------
// Wire-value decoders (server sends camelCase wire values per roles.ts)
// ---------------------------------------------------------------------------

/// Server role wire values are camelCase ('fleetOwner', 'operationsAdmin'…).
UserRole parseUserRole(String? wire) => switch (wire) {
  'customer' => UserRole.customer,
  'driver' => UserRole.driver,
  'fleetOwner' || 'fleet_owner' => UserRole.fleetOwner,
  'operationsAdmin' || 'operations_admin' => UserRole.operationsAdmin,
  'verificationAdmin' || 'verification_admin' => UserRole.verificationAdmin,
  'financeAdmin' || 'finance_admin' => UserRole.financeAdmin,
  'superAdmin' || 'super_admin' => UserRole.superAdmin,
  _ => UserRole.customer,
};

/// Server account-status wire values are SNAKE_CASE ('PROFILE_INCOMPLETE'…).
AccountStatus parseAccountStatus(String? wire) => switch (wire) {
  'ACTIVE' || 'active' => AccountStatus.active,
  'PROFILE_INCOMPLETE' || 'profile_incomplete' => AccountStatus.profileIncomplete,
  'PENDING_VERIFICATION' || 'pending_verification' => AccountStatus.pendingVerification,
  'SUSPENDED' || 'suspended' => AccountStatus.suspended,
  _ => AccountStatus.active,
};

/// Booking status wire values are UPPER_SNAKE ('REQUESTED', 'DRIVER_ACCEPTED'…).
String parseBookingStatusWire(String? wire) =>
    (wire ?? 'REQUESTED').toUpperCase();

/// Amounts arrive as JSON strings (BigInt serialization) — parse leniently.
int parseIntAmount(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Parses an ISO timestamp leniently; falls back to epoch.
DateTime parseDateTime(dynamic value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// Produces a stable idempotency key for a logical booking attempt.
/// Deterministic per (draft, vehicle, start) so double-taps/retries reuse it.
String bookingIdempotencyKey({
  required String draftId,
  required String vehicleId,
  required DateTime start,
}) =>
    'bk-${draftId.hashCode.abs().toRadixString(36)}'
    '-${vehicleId.hashCode.abs().toRadixString(36)}'
    '-${start.millisecondsSinceEpoch ~/ 60000}';
