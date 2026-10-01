/// Canonical trip direction — mirrors `backend/src/common/domain/trip-type.ts`.
///
/// Wire values are ONE_WAY | ROUND_TRIP; the customer-facing label for
/// ROUND_TRIP is "Both Way". The SERVER decides the billed distance
/// (ONE_WAY = pickup→destination once; ROUND_TRIP = ×2) — the client only
/// declares intent and echoes the server's `trip_type` back.
enum TripType {
  oneWay,
  roundTrip;

  /// The value the backend DTO (`@IsIn(TRIP_TYPE_VALUES)`) accepts.
  String get wire => switch (this) {
        TripType.oneWay => 'ONE_WAY',
        TripType.roundTrip => 'ROUND_TRIP',
      };

  /// Customer-facing label, matching the home panel segmented control.
  String get label => switch (this) {
        TripType.oneWay => 'One Way',
        TripType.roundTrip => 'Both Way',
      };

  /// Parses a wire value from a server payload; unknown/blank → oneWay
  /// (the backend's own default).
  static TripType fromWire(String? value) =>
      value == 'ROUND_TRIP' ? TripType.roundTrip : TripType.oneWay;
}
