/// Validation rules for the booking location fields.
///
/// The backend is authoritative: `SubmitBookingDto` (and the identical
/// `SubmitGroupBookingDto`) declare
///
/// ```ts
/// @IsString() @Length(5, 500) pickupAddress!: string;
/// @IsString() @Length(5, 500) destinationAddress!: string;
/// @IsString() @Length(2, 50)  city!: string;
/// ```
///
/// Mirroring those bounds here means the customer is told what to fix while
/// typing, instead of the request being rejected by the server after review.
/// The constants are asserted against the backend's own messages in
/// `test/features/bookings/booking_api_contract_test.dart`.
abstract final class BookingLocationRules {
  static const int addressMinLength = 5;
  static const int addressMaxLength = 500;
  static const int cityMinLength = 2;
  static const int cityMaxLength = 50;

  /// A trimmed address that satisfies the server's `@Length(5, 500)` rule.
  static bool isAddressValid(String value) {
    final trimmed = value.trim();
    return trimmed.length >= addressMinLength &&
        trimmed.length <= addressMaxLength;
  }

  static bool isCityValid(String value) {
    final trimmed = value.trim();
    return trimmed.length >= cityMinLength &&
        trimmed.length <= cityMaxLength;
  }

  /// Returns the message to show for an invalid address, or null when valid.
  /// [label] is the user-visible field name, e.g. 'Pickup address'.
  static String? addressError(String value, {required String label}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter the $label.';
    if (trimmed.length < addressMinLength) {
      return '$label must be at least $addressMinLength characters.';
    }
    if (trimmed.length > addressMaxLength) {
      return '$label must be $addressMaxLength characters or fewer.';
    }
    return null;
  }

  static String? cityError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Select the service city.';
    if (!isCityValid(trimmed)) {
      return 'City must be between $cityMinLength and $cityMaxLength characters.';
    }
    return null;
  }
}
