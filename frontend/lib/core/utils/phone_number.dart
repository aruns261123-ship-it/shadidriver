/// Canonical phone-number normalization for ShadiDriver.
///
/// The backend auth contract (`PHONE_NUMBER_REGEX` + `INDIAN_MOBILE_REGEX` in
/// `backend/src/auth/dto/auth.dto.ts`) requires an E.164 JSON string of the
/// form `+91XXXXXXXXXX` where the 10-digit subscriber number starts 6-9.
///
/// Normalization lives here — not scattered across screens/repositories — so
/// every registration/login request emits exactly the same wire value:
/// user input → [tryNormalizeIndian] → `"phoneNumber": "+91XXXXXXXXXX"`.
abstract final class PhoneNumber {
  /// Indian mobile subscriber numbers always start with 6-9.
  static final RegExp _indianMobile = RegExp(r'^[6-9]\d{9}$');

  /// Returns the canonical `+91XXXXXXXXXX` form of [input], or `null` when it
  /// is not a valid Indian mobile number.
  ///
  /// Accepts local and international input, tolerating spaces/formatting and
  /// common prefix mistakes:
  ///   - `9876543210`          → `+919876543210`
  ///   - `09876543210`         → `+919876543210` (trunk `0`)
  ///   - `+91 98765 43210`     → `+919876543210`
  ///   - `919876543210`        → `+919876543210`
  ///   - `0091 9876543210`     → `+919876543210`
  ///
  /// Rejects anything that is not a 10-digit `[6-9]\d{9}` subscriber number,
  /// so a malformed value is never sent to the backend and never duplicated
  /// with a second country code.
  static String? tryNormalizeIndian(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    // Strip a leading international prefix, honouring the longest first so a
    // `91` country code inside `0091…` is not misread.
    if (digits.startsWith('0091')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('91') && digits.length > 10) {
      digits = digits.substring(2);
    }

    // Strip a single national trunk `0` (e.g. `09876543210`).
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length != 10 || !_indianMobile.hasMatch(digits)) return null;
    return '+91$digits';
  }

  /// Whether [input] is a valid Indian mobile number in any accepted form.
  static bool isValidIndian(String input) => tryNormalizeIndian(input) != null;
}
