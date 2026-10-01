/**
 * Canonical trip direction, end to end: search → availability → quote →
 * booking. The Flutter client sends exactly these wire values.
 *
 * Billable distance rule (server-authoritative, per product policy):
 *   ONE_WAY     → pickup → destination
 *   ROUND_TRIP  → pickup → destination × 2  ("BOTH WAY" in the UI)
 *
 * The UI label ("BOTH WAY") is presentation; the wire and storage value is
 * always ONE_WAY | ROUND_TRIP.
 */
export enum TripType {
  ONE_WAY = 'ONE_WAY',
  ROUND_TRIP = 'ROUND_TRIP',
}

export const TRIP_TYPE_VALUES: readonly string[] = Object.values(TripType);

/** True when the value is a canonical trip type (case-insensitive). */
export function isTripType(value: unknown): value is TripType {
  return (
    typeof value === 'string' &&
    TRIP_TYPE_VALUES.includes(value.toUpperCase())
  );
}

/** Parses a wire value; undefined/blank → ONE_WAY (the default direction). */
export function parseTripType(value: unknown): TripType {
  if (!isTripType(value)) return TripType.ONE_WAY;
  return value.toUpperCase() as TripType;
}

/**
 * Server-side billable distance for a trip.
 *
 * [routeDistanceKm] is the ONE-WAY route distance (pickup → destination) as
 * measured on the route service. The server, never the client, decides the
 * billed amount: a ROUND_TRIP bills the route twice.
 */
export function billableDistanceKm(
  routeDistanceKm: number | undefined | null,
  tripType: TripType | undefined | null,
): number {
  const oneWay = routeDistanceKm ?? 0;
  return tripType === TripType.ROUND_TRIP ? oneWay * 2 : oneWay;
}
