import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/core/network/interceptors/error_interceptor.dart';

void main() {
  group('NetworkErrorMapper Tests', () {
    final reqOptions = RequestOptions(path: '/api/v1/test');

    test('maps connection timeout to TimeoutFailure', () {
      final dioErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.connectionTimeout,
      );

      final failure = NetworkErrorMapper.map(dioErr);
      expect(failure, isA<TimeoutFailure>());
    });

    test('maps connection error to NetworkFailure', () {
      final dioErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.connectionError,
      );

      final failure = NetworkErrorMapper.map(dioErr);
      expect(failure, isA<NetworkFailure>());
    });

    test('maps 401 response to UnauthorizedFailure', () {
      final dioErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 401,
          data: {
            'error': {'message': 'Session expired', 'code': 'TOKEN_EXPIRED'},
          },
        ),
      );

      final failure = NetworkErrorMapper.map(dioErr);
      expect(failure, isA<UnauthorizedFailure>());
      expect(failure.message, equals('Session expired'));
      expect(failure.code, equals('TOKEN_EXPIRED'));
    });

    test('maps 403 response to ForbiddenFailure', () {
      final dioErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 403,
          data: {
            'error': {'message': 'Access denied'},
          },
        ),
      );

      final failure = NetworkErrorMapper.map(dioErr);
      expect(failure, isA<ForbiddenFailure>());
      expect(failure.message, equals('Access denied'));
    });

    test('maps 404 response to NotFoundFailure', () {
      final dioErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 404,
          data: {
            'error': {'message': 'Chauffeur not found'},
          },
        ),
      );

      final failure = NetworkErrorMapper.map(dioErr);
      expect(failure, isA<NotFoundFailure>());
    });

    test('maps 409 response to ConflictFailure', () {
      final dioErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 409,
          data: {
            'error': {'message': 'Slot double-booked'},
          },
        ),
      );

      final failure = NetworkErrorMapper.map(dioErr);
      expect(failure, isA<ConflictFailure>());
    });

    test('maps 500 response to ServerFailure', () {
      final dioErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 500,
          data: {
            'error': {'message': 'Internal database deadlock'},
          },
        ),
      );

      final failure = NetworkErrorMapper.map(dioErr);
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, equals(500));
    });
  });
}
