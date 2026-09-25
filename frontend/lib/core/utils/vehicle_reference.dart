/// Display helper for backend identifiers.
///
/// Vehicles, chauffeurs and bookings are identified by 36-character UUIDs on
/// the real backend. A full UUID is wider than a phone card, is meaningless to
/// a customer, and forces the surrounding row to overflow. Cards therefore show
/// the leading segment only and keep the exact value available through a
/// tooltip/semantics label (and on the detail screens).
abstract final class VehicleReference {
  /// Number of leading characters kept when an id is shortened.
  static const int shortLength = 8;

  static String shorten(String id) {
    final trimmed = id.trim();
    if (trimmed.length <= shortLength) return trimmed;
    return '${trimmed.substring(0, shortLength)}…';
  }

  /// True when [shorten] would drop characters — used by callers that want to
  /// attach a tooltip/semantics label with the exact value.
  static bool isShortened(String id) => id.trim().length > shortLength;
}
