import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('formats hundreds of rupees without decimals', () {
      expect(CurrencyFormatter.formatPaise(50000), equals('₹500'));
    });

    test('formats thousands of rupees with Indian comma grouping', () {
      expect(CurrencyFormatter.formatPaise(150000), equals('₹1,500'));
      expect(CurrencyFormatter.formatPaise(1888000), equals('₹18,880'));
    });

    test('formats lakhs of rupees with correct Indian grouping', () {
      expect(CurrencyFormatter.formatPaise(15000000), equals('₹1,50,000'));
      expect(CurrencyFormatter.formatPaise(100000000), equals('₹10,00,000'));
    });

    test('formats with decimals when requested', () {
      expect(
        CurrencyFormatter.formatPaise(150050, showDecimals: true),
        equals('₹1,500.50'),
      );
    });
  });
}
