import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/utils/phone_number.dart';

void main() {
  group('PhoneNumber.tryNormalizeIndian', () {
    test('accepts a bare 10-digit number and prefixes +91', () {
      expect(PhoneNumber.tryNormalizeIndian('9876543210'), '+919876543210');
    });

    test('strips a national trunk 0', () {
      expect(PhoneNumber.tryNormalizeIndian('09876543210'), '+919876543210');
    });

    test('strips a +91 country code (no duplicate prefix)', () {
      expect(PhoneNumber.tryNormalizeIndian('+919876543210'), '+919876543210');
      expect(PhoneNumber.tryNormalizeIndian('919876543210'), '+919876543210');
    });

    test('strips 0091 international prefix', () {
      expect(PhoneNumber.tryNormalizeIndian('0091 9876543210'), '+919876543210');
    });

    test('tolerates spaces and formatting characters', () {
      expect(PhoneNumber.tryNormalizeIndian('+91 98765 43210'), '+919876543210');
      expect(PhoneNumber.tryNormalizeIndian('98765-43210'), '+919876543210');
    });

    test('rejects numbers that do not start 6-9', () {
      expect(PhoneNumber.tryNormalizeIndian('1234567890'), isNull);
      expect(PhoneNumber.tryNormalizeIndian('0987654321'), isNull);
    });

    test('rejects wrong lengths', () {
      expect(PhoneNumber.tryNormalizeIndian('987654321'), isNull);
      expect(PhoneNumber.tryNormalizeIndian('98765432101'), isNull);
      expect(PhoneNumber.tryNormalizeIndian(''), isNull);
      expect(PhoneNumber.tryNormalizeIndian('abc'), isNull);
    });

    test('isValidIndian mirrors tryNormalizeIndian', () {
      expect(PhoneNumber.isValidIndian('9876543210'), isTrue);
      expect(PhoneNumber.isValidIndian('1234567890'), isFalse);
    });
  });
}
