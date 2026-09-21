import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/core/result/result.dart';

void main() {
  group('Result Architecture Tests', () {
    test('Success stores data and flags isSuccess correctly', () {
      const result = Result.success('booking_123');

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals('booking_123'));
      expect(result.failureOrNull, isNull);
    });

    test('Failure stores AppFailure and flags isFailure correctly', () {
      const failure = NetworkFailure('No connection');
      const result = Result<String>.failure(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, equals(failure));
    });

    test('when executes success branch on Success', () {
      const result = Result.success(42);

      final outcome = result.when(
        success: (data) => 'Value: $data',
        failure: (f) => 'Failed: ${f.message}',
      );

      expect(outcome, equals('Value: 42'));
    });

    test('when executes failure branch on Failure', () {
      const result = Result<int>.failure(UnauthorizedFailure('Token expired'));

      final outcome = result.when(
        success: (data) => 'Value: $data',
        failure: (f) => 'Failed: ${f.message}',
      );

      expect(outcome, equals('Failed: Token expired'));
    });

    test('map transforms value on Success and leaves Failure unchanged', () {
      const success = Result.success(10);
      final mappedSuccess = success.map((v) => v * 2);

      expect(mappedSuccess.dataOrNull, equals(20));

      const failure = Result<int>.failure(ServerFailure('Down'));
      final mappedFailure = failure.map((v) => v * 2);

      expect(mappedFailure.isFailure, isTrue);
      expect(mappedFailure.failureOrNull?.message, equals('Down'));
    });

    test('fold executes respective callbacks', () {
      const success = Result.success('ok');
      expect(success.fold((f) => 'fail', (d) => 'win: $d'), equals('win: ok'));

      const failure = Result<String>.failure(NotFoundFailure('404'));
      expect(
        failure.fold((f) => 'fail: ${f.message}', (d) => 'win'),
        equals('fail: 404'),
      );
    });
  });
}
