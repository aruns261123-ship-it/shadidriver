import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/errors/failures.dart';

void main() {
  group('AppFailure Hierarchy Tests', () {
    test('NetworkFailure default code and message', () {
      const failure = NetworkFailure();
      expect(failure.code, equals('NETWORK_ERROR'));
      expect(failure.message, contains('internet connection'));
    });

    test('TimeoutFailure code and message', () {
      const failure = TimeoutFailure('Custom timeout');
      expect(failure.code, equals('TIMEOUT_ERROR'));
      expect(failure.message, equals('Custom timeout'));
    });

    test('ValidationFailure holds field errors map', () {
      const failure = ValidationFailure(
        'Invalid parameters',
        code: 'BAD_INPUT',
        fieldErrors: {
          'phone': ['Must be 10 digits'],
        },
      );

      expect(failure.fieldErrors?['phone']?.first, equals('Must be 10 digits'));
      expect(failure.code, equals('BAD_INPUT'));
    });

    test('ServerFailure records status code', () {
      const failure = ServerFailure(
        'Internal error',
        'INTERNAL_500',
        null,
        500,
      );
      expect(failure.statusCode, equals(500));
      expect(failure.code, equals('INTERNAL_500'));
    });

    test('StorageFailure default code', () {
      const failure = StorageFailure();
      expect(failure.code, equals('STORAGE_ERROR'));
    });
  });
}
