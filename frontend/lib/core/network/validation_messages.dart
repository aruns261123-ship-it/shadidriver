/// Turns the backend's `error.details.validation` payload (class-validator
/// message strings) into messages a customer can act on.
///
/// Two very different failures used to be indistinguishable in the UI:
///
///  1. **Contract drift** — the client sent a field the server does not
///     declare. class-validator reports `property x should not exist`
///     (`forbidNonWhitelisted`). Nothing the customer types can fix this: the
///     app itself is stale.
///  2. **Value rejection** — the field is supported, but the *value* violates a
///     declared rule (`pickupAddress must be longer than or equal to 5
///     characters`). The customer fixes this by editing the field.
///
/// Reporting (2) as if it were (1) tells the customer to update an app that is
/// already up to date and hides the real problem, so the two are kept apart
/// here and only (1) may claim the app is out of date.
library;

/// The class-validator rule a message came from.
enum ValidationRule {
  /// `property x should not exist` — the server does not accept this field.
  unknownProperty,
  required,
  minLength,
  maxLength,
  minimum,
  maximum,
  oneOf,
  pattern,
  type,
  other,
}

/// A single parsed class-validator message.
class FieldError {
  final String field;
  final ValidationRule rule;

  /// The numeric bound for length/minimum/maximum rules.
  final int? limit;

  /// The original server string (kept for diagnostics only — never shown to a
  /// customer).
  final String raw;

  const FieldError({
    required this.field,
    required this.rule,
    required this.raw,
    this.limit,
  });

  @override
  String toString() => '$field(${rule.name}${limit == null ? '' : ':$limit'})';
}

final _unknownProperty = RegExp(r'^property (\S+) should not exist');
final _length = RegExp(r'^(\S+) must be (longer than or equal to|shorter than or equal to) (\d+) characters');
final _bound = RegExp(r'^(\S+) must not be (less than|greater than) (\d+)');
final _empty = RegExp(r'^(\S+) should not be empty');
final _oneOf = RegExp(r'^(\S+) must be one of the following values');
final _type = RegExp(r'^(\S+) must be (a|an) (string|number|integer number|boolean|array|date string|ISO 8601 date string|email|enum)');

/// Parses raw class-validator messages. Unrecognised messages keep their field
/// name (first token) and are classified as [ValidationRule.other] so a custom
/// message never disappears from [FieldError] bookkeeping.
List<FieldError> parseFieldErrors(Iterable<String> messages) {
  final errors = <FieldError>[];
  for (final raw in messages) {
    if (raw.trim().isEmpty) continue;
    final unknown = _unknownProperty.firstMatch(raw);
    if (unknown != null) {
      errors.add(FieldError(
        field: unknown.group(1)!,
        rule: ValidationRule.unknownProperty,
        raw: raw,
      ));
      continue;
    }
    final length = _length.firstMatch(raw);
    if (length != null) {
      errors.add(FieldError(
        field: length.group(1)!,
        rule: length.group(2)!.startsWith('longer')
            ? ValidationRule.minLength
            : ValidationRule.maxLength,
        limit: int.tryParse(length.group(3)!),
        raw: raw,
      ));
      continue;
    }
    final bound = _bound.firstMatch(raw);
    if (bound != null) {
      errors.add(FieldError(
        field: bound.group(1)!,
        rule: bound.group(2) == 'less than'
            ? ValidationRule.minimum
            : ValidationRule.maximum,
        limit: int.tryParse(bound.group(3)!),
        raw: raw,
      ));
      continue;
    }
    final empty = _empty.firstMatch(raw);
    if (empty != null) {
      errors.add(FieldError(
        field: empty.group(1)!,
        rule: ValidationRule.required,
        raw: raw,
      ));
      continue;
    }
    if (_oneOf.hasMatch(raw)) {
      errors.add(FieldError(
        field: _oneOf.firstMatch(raw)!.group(1)!,
        rule: ValidationRule.oneOf,
        raw: raw,
      ));
      continue;
    }
    if (_type.hasMatch(raw)) {
      errors.add(FieldError(
        field: _type.firstMatch(raw)!.group(1)!,
        rule: ValidationRule.type,
        raw: raw,
      ));
      continue;
    }
    final field = raw.split(' ').first;
    errors.add(FieldError(
      field: field.isEmpty ? raw : field,
      rule: raw.contains('must match') || raw.contains('must be an E.164')
          ? ValidationRule.pattern
          : ValidationRule.other,
      raw: raw,
    ));
  }
  return errors;
}

/// Fields the server does NOT declare. These are the only failures that mean
/// "this build of the app is out of date".
List<String> unknownProperties(List<FieldError> errors) {
  final seen = <String>[];
  for (final e in errors) {
    if (e.rule == ValidationRule.unknownProperty && !seen.contains(e.field)) {
      seen.add(e.field);
    }
  }
  return seen;
}

/// Human labels for fields we know how to explain. Unknown fields fall back to
/// a humanized form of their wire name, so a message stays specific without
/// inventing vocabulary.
const Map<String, String> kFieldLabels = {
  'phoneNumber': 'mobile number',
  'displayName': 'name',
  'role': 'account type',
  'sessionId': 'verification session',
  'otpCode': 'verification code',
  'refreshToken': 'session',
  'serviceCategoryId': 'service',
  'vehicleTypeId': 'vehicle',
  'ceremonyType': 'ceremony',
  'ceremonialAttire': 'ceremonial attire',
  'specialInstructions': 'special instructions',
  'serviceStartTime': 'service start',
  'serviceEndTime': 'service end',
  'city': 'city',
  'pickupAddress': 'pickup address',
  'destinationAddress': 'destination address',
  'venueName': 'venue name',
  'routeDistanceKm': 'route distance',
  'primaryContactName': 'contact name',
  'primaryContactPhone': 'contact phone number',
  'passengerCount': 'passenger count',
  'selectedAddonIds': 'selected add-ons',
  'idempotencyKey': 'idempotency key',
};

/// Messages that are more useful than anything derivable from the rule, keyed
/// by field (used for the auth form fields, which have bespoke wording).
const Map<String, String> kFriendlyFieldMessages = {
  'phoneNumber': 'Enter a valid mobile number.',
  'displayName': 'Name must be at least 2 characters.',
  'role': 'Choose a valid account type.',
  'sessionId': 'Your verification session expired. Request a new code.',
  'otpCode': 'Enter the 6-digit code we sent you.',
  'refreshToken': 'Your session expired. Please sign in again.',
};

/// `pickupAddress` → `pickup address`; `routeDistanceKm` → `route distance km`.
String humanizeField(String field) {
  final spaced = field
      .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .trim()
      .toLowerCase();
  return spaced.isEmpty ? field : spaced;
}

String _label(String field) => kFieldLabels[field] ?? humanizeField(field);

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// Builds a customer-facing sentence for one field's failure.
String describeFieldError(FieldError error) {
  final label = _label(error.field);
  return switch (error.rule) {
    ValidationRule.minLength =>
      '${_capitalize(label)} must be at least ${error.limit ?? 0} characters.',
    ValidationRule.maxLength =>
      '${_capitalize(label)} must be ${error.limit ?? 0} characters or fewer.',
    ValidationRule.minimum =>
      '${_capitalize(label)} must be at least ${error.limit ?? 0}.',
    ValidationRule.maximum =>
      '${_capitalize(label)} must be ${error.limit ?? 0} or less.',
    ValidationRule.required => 'Enter $label.',
    ValidationRule.oneOf => 'Choose a valid $label.',
    ValidationRule.pattern => 'Enter a valid $label.',
    ValidationRule.type => 'Enter a valid $label.',
    ValidationRule.unknownProperty || ValidationRule.other =>
      '${_capitalize(label)} is not valid.',
  };
}

/// Chooses what to show the customer for a set of field errors.
///
/// * Genuine contract drift (unknown properties) → an explicit "this build is
///   out of date" message, because nothing the customer types can fix it.
/// * A supported field whose value is rejected → the specific, actionable
///   sentence for the first failing field, so it matches the error the user
///   can actually see in the form.
///
/// Returns `null` when nothing better than the server's own message exists.
String? customerValidationMessage(Map<String, List<String>> fieldErrors) {
  final errors = <FieldError>[];
  for (final entry in fieldErrors.entries) {
    errors.addAll(parseFieldErrors(entry.value));
  }

  final unknown = unknownProperties(errors);
  if (unknown.isNotEmpty) {
    return 'The app sent an unsupported field (${unknown.join(', ')}). '
        'Please update to the latest version.';
  }

  for (final field in fieldErrors.keys) {
    final explicit = kFriendlyFieldMessages[field];
    if (explicit != null) return explicit;
  }
  for (final error in errors) {
    return describeFieldError(error);
  }
  return null;
}
