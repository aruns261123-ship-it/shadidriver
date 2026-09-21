/// Base application exception.
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => '$runtimeType: $message (${code ?? "NO_CODE"})';
}

class ServerException extends AppException {
  final int? statusCode;
  const ServerException(super.message, [super.code, this.statusCode]);
}

class CacheException extends AppException {
  const CacheException(super.message, [super.code]);
}

class AuthException extends AppException {
  const AuthException(super.message, [super.code]);
}

class ValidationException extends AppException {
  final Map<String, List<String>>? errors;
  const ValidationException(super.message, [super.code, this.errors]);
}
