import 'package:dio/dio.dart';
import '../../errors/failures.dart';

/// Maps [DioException] instances into domain-safe [AppFailure] types.
class NetworkErrorMapper {
  static AppFailure map(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutFailure(
          'Request timed out. Please check your network connection.',
        );

      case DioExceptionType.connectionError:
        return const NetworkFailure(
          'Unable to connect to the server. Please check your connection.',
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;

        String message = 'Server error occurred.';
        String? code;
        Map<String, List<String>>? fieldErrors;

        if (responseData is Map<String, dynamic>) {
          if (responseData['error'] is Map<String, dynamic>) {
            final errObj = responseData['error'] as Map<String, dynamic>;
            message = errObj['message']?.toString() ?? message;
            code = errObj['code']?.toString();
          } else if (responseData['message'] != null) {
            message = responseData['message'].toString();
          }
        }

        switch (statusCode) {
          case 400:
            return ValidationFailure(
              message,
              code: code ?? 'BAD_REQUEST',
              fieldErrors: fieldErrors,
            );
          case 401:
            return UnauthorizedFailure(message, code);
          case 403:
            return ForbiddenFailure(message, code);
          case 404:
            return NotFoundFailure(message, code);
          case 409:
            return ConflictFailure(message, code);
          case 422:
            return ValidationFailure(
              message,
              code: code ?? 'UNPROCESSABLE_ENTITY',
              fieldErrors: fieldErrors,
            );
          case 500:
          case 502:
          case 503:
          case 504:
            return ServerFailure(message, code, null, statusCode);
          default:
            return UnknownFailure(message, code, error);
        }

      case DioExceptionType.cancel:
        return const UnknownFailure(
          'Request was cancelled.',
          'REQUEST_CANCELLED',
        );

      case DioExceptionType.badCertificate:
        return const NetworkFailure(
          'Security verification failed. Invalid SSL certificate.',
          'BAD_CERTIFICATE',
        );

      case DioExceptionType.unknown:
        return UnknownFailure(
          'An unexpected error occurred: ${error.message}',
          'UNKNOWN_ERROR',
          error,
        );
    }
  }
}
