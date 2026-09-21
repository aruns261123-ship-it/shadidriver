/// Contract for application logging.
/// Business logic and network interceptors log through this interface.
abstract interface class AppLogger {
  void debug(String message, [Object? error, StackTrace? stackTrace]);
  void info(String message, [Object? error, StackTrace? stackTrace]);
  void warning(String message, [Object? error, StackTrace? stackTrace]);
  void error(String message, [Object? error, StackTrace? stackTrace]);

  /// Sanitize and redact sensitive data from strings or keys.
  static String redact(String input) {
    // Redact Bearer tokens
    var sanitized = input.replaceAll(
      RegExp(r'(Bearer\s+)[A-Za-z0-9\-_.]+', caseSensitive: false),
      r'$1[REDACTED_TOKEN]',
    );

    // Redact OTPs (4-8 digits in context)
    sanitized = sanitized.replaceAll(
      RegExp(
        r'("?(?:otp|code|pin)"?\s*[:=]\s*"?)\d{4,8}("?)',
        caseSensitive: false,
      ),
      r'$1[REDACTED_OTP]$2',
    );

    // Redact Passwords
    sanitized = sanitized.replaceAll(
      RegExp(
        r'("?(?:password|secret)"?\s*[:=]\s*"?[^",\s]+"?)([,}\s]?)',
        caseSensitive: false,
      ),
      r'"password": "[REDACTED]"$2',
    );

    // Redact Aadhaar numbers (12 digits)
    sanitized = sanitized.replaceAll(
      RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?(\d{4})\b'),
      r'XXXX-XXXX-$1',
    );

    // Redact PAN numbers (5 letters, 4 digits, 1 letter)
    sanitized = sanitized.replaceAll(
      RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b', caseSensitive: false),
      r'[REDACTED_PAN]',
    );

    return sanitized;
  }
}
