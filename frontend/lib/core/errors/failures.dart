/// Base typed failure class for ShadiDriver domain and data layers.
/// Domain and presentation code handle these typed failures instead of raw exceptions.
sealed class AppFailure {
  final String message;
  final String? code;
  final Object? cause;

  const AppFailure(this.message, {this.code, this.cause});

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

/// Failure due to lack of network connection or DNS resolution error.
final class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'No active internet connection. Please check your network.',
    String? code,
    Object? cause,
  ]) : super(code: code ?? 'NETWORK_ERROR', cause: cause);
}

/// Failure due to connection or read/write timeout.
final class TimeoutFailure extends AppFailure {
  const TimeoutFailure([
    super.message = 'The server request timed out. Please try again.',
    String? code,
    Object? cause,
  ]) : super(code: code ?? 'TIMEOUT_ERROR', cause: cause);
}

/// Failure due to 401 Unauthorized (token expired or invalid).
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([
    super.message = 'Your session has expired. Please log in again.',
    String? code,
    Object? cause,
  ]) : super(code: code ?? 'UNAUTHORIZED', cause: cause);
}

/// Failure due to 403 Forbidden (role permissions insufficient).
final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([
    super.message = 'You do not have permission to perform this action.',
    String? code,
    Object? cause,
  ]) : super(code: code ?? 'FORBIDDEN', cause: cause);
}

/// Failure due to 404 Not Found.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([
    super.message = 'The requested resource was not found.',
    String? code,
    Object? cause,
  ]) : super(code: code ?? 'NOT_FOUND', cause: cause);
}

/// Failure due to 409 Conflict (e.g., version conflict or slot already booked).
final class ConflictFailure extends AppFailure {
  const ConflictFailure([
    super.message = 'A conflicting state or reservation already exists.',
    String? code,
    Object? cause,
  ]) : super(code: code ?? 'CONFLICT', cause: cause);
}

/// Failure due to client-side input or parameter validation error.
final class ValidationFailure extends AppFailure {
  final Map<String, List<String>>? fieldErrors;

  const ValidationFailure(
    super.message, {
    super.code = 'VALIDATION_ERROR',
    super.cause,
    this.fieldErrors,
  });
}

/// Failure due to 5xx Internal Server Error.
final class ServerFailure extends AppFailure {
  final int? statusCode;

  const ServerFailure([
    super.message =
        'An unexpected server error occurred. Please try again later.',
    String? code,
    Object? cause,
    this.statusCode,
  ]) : super(code: code ?? 'SERVER_ERROR', cause: cause);
}

/// Failure due to secure storage or local persistence failure.
final class StorageFailure extends AppFailure {
  const StorageFailure([
    super.message = 'Failed to securely access local device storage.',
    String? code,
    Object? cause,
  ]) : super(code: code ?? 'STORAGE_ERROR', cause: cause);
}

/// Unknown or unclassified failure.
final class UnknownFailure extends AppFailure {
  const UnknownFailure([
    super.message = 'An unexpected error occurred.',
    String? code,
    Object? cause,
  ]) : super(code: code ?? 'UNKNOWN_ERROR', cause: cause);
}
