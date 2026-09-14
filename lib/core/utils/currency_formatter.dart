/// Utility for formatting Indian Rupee currency values stored in Paise (cents).
abstract final class CurrencyFormatter {
  /// Converts an amount in Indian Paise to formatted INR string (e.g. 150000 -> "₹1,500.00").
  static String formatPaise(int paise, {bool showDecimals = false}) {
    final rupees = paise / 100.0;
    if (showDecimals) {
      return '₹${_formatIndianNumber(rupees.toStringAsFixed(2))}';
    } else {
      return '₹${_formatIndianNumber(rupees.round().toString())}';
    }
  }

  /// Formats a number string with the Indian numbering system (Lakhs and Crores).
  static String _formatIndianNumber(String numStr) {
    final parts = numStr.split('.');
    String whole = parts[0];
    final decimal = parts.length > 1 ? '.${parts[1]}' : '';

    final isNegative = whole.startsWith('-');
    if (isNegative) whole = whole.substring(1);

    if (whole.length <= 3) {
      return (isNegative ? '-' : '') + whole + decimal;
    }

    final lastThree = whole.substring(whole.length - 3);
    final remaining = whole.substring(0, whole.length - 3);

    final buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    buffer.write(',$lastThree');

    return (isNegative ? '-' : '') + buffer.toString() + decimal;
  }
}
