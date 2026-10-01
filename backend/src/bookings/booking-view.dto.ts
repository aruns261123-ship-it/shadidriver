/**
 * Role-scoped booking views (privacy DTOs).
 *
 * One booking row, three audiences:
 *   CustomerBookingDto — the customer's own booking. The chauffeur is
 *     anonymous by design ("vehicle and chauffeur verified by ShadiDriver"):
 *     no driver name, no driver phone, no partner identity, no internal
 *     event metadata.
 *   DriverAssignmentDto — what an assigned chauffeur needs to execute the
 *     duty, and nothing more (host name/phone for the authorized trip).
 *   AdminBookingDto — the full operational picture, internal notes included.
 */

const ADMIN_ROLES = ['operationsAdmin', 'verificationAdmin', 'financeAdmin', 'superAdmin'];

export function isAdminRole(role: string): boolean {
  return ADMIN_ROLES.includes(role);
}

interface BookingRowLike {
  id: string;
  referenceCode?: string | null;
  ceremonyType: string;
  city: string;
  serviceStartTime: Date;
  serviceEndTime: Date;
  pickupAddress: string;
  destinationAddress: string;
  passengerCount: number;
  estimatedTotalPaise: bigint;
  advanceTokenPaise: bigint;
  isAdvancePaid: boolean;
  status: string;
  tripType?: string | null;
  submittedAt?: Date | null;
  customer: { id: string; fullName: string | null; phoneNumber: string };
  driver?:
    | {
        id: string;
        user: { fullName: string | null; phoneNumber: string } | null;
      }
    | null;
  vehicle?: {
    displayName?: string | null;
    fleetCode?: string | null;
    vehicleType?: { displayName?: string | null } | null;
  } | null;
  events?: Array<{
    fromStatus: string;
    toStatus: string;
    eventReason: string | null;
    createdAt: Date;
    eventMetadata?: unknown;
  }> | null;
}

/** Model display name + fleet code (e.g. "BMW 5 Series SD-F-012"). */
function vehicleLabel(v: BookingRowLike['vehicle']): string | null {
  if (!v) return null;
  const name = v.displayName ?? v.vehicleType?.displayName ?? '';
  const label = `${name} ${v.fleetCode ?? ''}`.trim();
  return label.length > 0 ? label : null;
}

export class CustomerBookingDto {
  static from(b: BookingRowLike) {
    return {
      id: b.id,
      reference_code: b.referenceCode ?? null,
      status: b.status,
      submitted_at: b.submittedAt ?? null,
      trip_type: b.tripType ?? 'ONE_WAY',
      ceremony_type: b.ceremonyType,
      city: b.city,
      /** The customer chose the CAR — it stays visible; only the chauffeur is anonymous. */
      vehicle_name: vehicleLabel(b.vehicle),
      pickup_address: b.pickupAddress,
      destination_address: b.destinationAddress,
      service_start_time: b.serviceStartTime,
      service_end_time: b.serviceEndTime,
      passenger_count: b.passengerCount,
      estimated_total_paise: b.estimatedTotalPaise.toString(),
      advance_token_paise: b.advanceTokenPaise.toString(),
      is_advance_paid: b.isAdvancePaid,
      /** Privacy model: the platform stands behind the service quality. */
      chauffeur_verification:
        b.driver != null
          ? 'Vehicle and chauffeur verified by ShadiDriver'
          : 'Vehicle allocation pending — ShadiDriver operations is arranging your fleet',
      driver: null,
    };
  }
}

export class DriverAssignmentDto {
  static from(b: BookingRowLike) {
    return {
      id: b.id,
      reference_code: b.referenceCode ?? null,
      status: b.status,
      ceremony_type: b.ceremonyType,
      city: b.city,
      /** The duty's car (model + fleet code) — no partner/owner identity. */
      vehicle_name: vehicleLabel(b.vehicle),
      pickup_address: b.pickupAddress,
      destination_address: b.destinationAddress,
      service_start_time: b.serviceStartTime,
      service_end_time: b.serviceEndTime,
      passenger_count: b.passengerCount,
      /** Operational minimum for an AUTHORIZED assignment. */
      host_name: b.customer.fullName,
      host_phone: b.customer.phoneNumber,
    };
  }
}

export class AdminBookingDto {
  static from(b: BookingRowLike) {
    return {
      id: b.id,
      reference_code: b.referenceCode ?? null,
      status: b.status,
      trip_type: b.tripType ?? 'ONE_WAY',
      ceremony_type: b.ceremonyType,
      city: b.city,
      service_start_time: b.serviceStartTime,
      service_end_time: b.serviceEndTime,
      pickup_address: b.pickupAddress,
      destination_address: b.destinationAddress,
      passenger_count: b.passengerCount,
      estimated_total_paise: b.estimatedTotalPaise.toString(),
      advance_token_paise: b.advanceTokenPaise.toString(),
      is_advance_paid: b.isAdvancePaid,
      customer: {
        id: b.customer.id,
        name: b.customer.fullName,
        phone: b.customer.phoneNumber,
      },
      assigned_chauffeur: b.driver
        ? {
            id: b.driver.id,
            name: b.driver.user?.fullName ?? null,
            phone: b.driver.user?.phoneNumber ?? null,
          }
        : null,
      events: (b.events ?? []).map((e) => ({
        from_status: e.fromStatus,
        to_status: e.toStatus,
        reason: e.eventReason ?? '',
        at: e.createdAt,
      })),
    };
  }
}
