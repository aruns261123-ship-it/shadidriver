/**
 * PUBLIC (unauthenticated) vehicle response DTOs.
 *
 * `GET /api/v1/vehicles*` is reachable without a token, and `GET /vehicles/:id`
 * on a marketplace that assigns chauffeurs internally must never expose the
 * chauffeur or the partner who owns the vehicle. Those are operational data:
 * a customer books a VEHICLE, ShadiDriver operations assigns the chauffeur.
 *
 * Enforcement here is structural — every field is named explicitly, nothing is
 * spread from the Prisma row, and {@link PUBLIC_VEHICLE_LIST_KEYS} /
 * {@link PUBLIC_VEHICLE_DETAIL_KEYS} are asserted by tests so that adding a
 * field is a deliberate, visible change rather than an accidental leak.
 */

/**
 * Indicative starting price in paise, as a string (BigInt), or `null` when no
 * tariff has been approved for the vehicle yet.
 *
 * It is deliberately nullable: the legacy `base_price_paise` column defaults to
 * 0, so publishing it directly made every newly onboarded partner vehicle
 * advertise "From ₹0". A price the platform has not approved is not a price —
 * the client must render "Price on request" instead.
 */
export interface PublicVehicleListItem {
  id: string;
  vehicle_type_id: string;
  /** Internal fleet reference — not the registration plate. */
  fleet_code: string;
  make: string;
  model: string;
  display_name: string;
  year: number;
  vehicle_class: string;
  seating_capacity: number;
  city: string;
  image_url: string | null;
  amenities: string[];
  verification_status: string;
  is_available: boolean;
  /** TRUE when a verified chauffeur is available for this vehicle. */
  has_verified_chauffeur: boolean;
  rating: number | null;
  review_count: number;
  price_indicator_paise: string | null;
}

export interface PublicVehicleDetail extends PublicVehicleListItem {
  color: string;
  fuel_type: string;
  air_conditioning: string;
  is_vintage: boolean;
  service_areas: string[];
  photos: string[];
  /** Aggregate document readiness only — never document rows. */
  documents_summary: { total: number; verified: number; expiring_soon: number };
  suitable_ceremonies: string[];
}

/**
 * Exhaustive key allow-lists. Any key not present here must never appear in a
 * public response; the contract tests assert both directions.
 */
export const PUBLIC_VEHICLE_LIST_KEYS = [
  'id',
  'vehicle_type_id',
  'fleet_code',
  'make',
  'model',
  'display_name',
  'year',
  'vehicle_class',
  'seating_capacity',
  'city',
  'image_url',
  'amenities',
  'verification_status',
  'is_available',
  'has_verified_chauffeur',
  'rating',
  'review_count',
  'price_indicator_paise',
] as const;

export const PUBLIC_VEHICLE_DETAIL_KEYS = [
  ...PUBLIC_VEHICLE_LIST_KEYS,
  'color',
  'fuel_type',
  'air_conditioning',
  'is_vintage',
  'service_areas',
  'photos',
  'documents_summary',
  'suitable_ceremonies',
] as const;

/**
 * Keys that must NEVER appear on any customer-facing vehicle payload. Kept as
 * an explicit list (rather than an omission) so the tests document intent.
 */
export const FORBIDDEN_CUSTOMER_VEHICLE_KEYS = [
  'chauffeur',
  'chauffeur_name',
  'chauffeur_id',
  'driver',
  'driver_id',
  'owner',
  'fleet_owner',
  'fleet_owner_id',
  'registration_number',
  'documents',
  'internal_notes',
  'pricing_versions',
] as const;

export interface PublicVehicleSource {
  id: string;
  fleetCode: string;
  vehicleTypeId: string;
  yearOfManufacture: number;
  color: string;
  fuelType: string;
  airConditioningType: string;
  isVintage: boolean;
  city: string;
  imageUrl: string | null;
  photoUrls: string[];
  amenityTags: string[];
  serviceAreas: string[];
  verificationStatus: string;
  isAvailable: boolean;
  /** The APPROVED tariff, if ShadiDriver commercial review has approved one. */
  approvedTariff: ApprovedTariff | null;
  vehicleType: {
    id: string;
    displayName: string;
    make: string;
    model: string;
    seatingCap: number;
    vehicleClass: string;
    imageUrl: string | null;
    amenityTags: string[];
  };
  /** Whether a VERIFIED chauffeur can be sourced for this vehicle. */
  hasVerifiedChauffeur: boolean;
  rating: number | null;
  reviewCount: number;
  documentCounts?: { total: number; verified: number; expiringSoon: number };
}

/** The entry tariff a customer may be quoted, before any quote is calculated. */
export interface ApprovedTariff {
  localIncludedKm: number | null;
  localAmountPaise: bigint | null;
  perKmPaise: bigint | null;
  hourlyPaise: bigint | null;
  fullDayPaise: bigint | null;
  overnightPaise: bigint | null;
  outstationPerDayPaise: bigint | null;
  outstationPerKmPaise: bigint | null;
}

/**
 * The cheapest entry point into the approved tariff — what "From ₹X" means.
 *
 * Only entry amounts count: per-km and per-hour rates are incremental and can
 * never be an actual price on their own. Returns null when nothing has been
 * approved, so an unpriced vehicle shows no figure at all.
 */
export function cheapestIndicativePaise(tariff: ApprovedTariff | null): bigint | null {
  if (!tariff) return null;
  const entries = [
    tariff.localAmountPaise,
    tariff.fullDayPaise,
    tariff.overnightPaise,
    tariff.outstationPerDayPaise,
  ].filter((v): v is bigint => v !== null && v > 0n);
  if (entries.length === 0) return null;
  return entries.reduce((min, v) => (v < min ? v : min));
}

/** Ceremonial suitability is a server decision, not a client-side guess. */
export function suitableCeremoniesForClass(vehicleClass: string): string[] {
  switch (vehicleClass.toUpperCase()) {
    case 'LUXURY_SEDAN':
      return ['Baraat', 'Groom Entry', 'Reception', 'Engagement'];
    case 'EXECUTIVE_MPV':
      return ['Guest Transport', 'Airport VIP', 'Family Escort'];
    case 'ULTRA_LUXURY':
      return ['Bride Entry', 'Groom Entry', 'Vidai', 'Royal Reception'];
    case 'PREMIUM_SUV':
      return ['Baraat', 'Guest Transport', 'Family Escort'];
    default:
      return ['Baraat', 'Vidai', 'Reception'];
  }
}

export function toPublicVehicleListItem(v: PublicVehicleSource): PublicVehicleListItem {
  return {
    id: v.id,
    vehicle_type_id: v.vehicleTypeId,
    fleet_code: v.fleetCode,
    make: v.vehicleType.make,
    model: v.vehicleType.model,
    display_name: v.vehicleType.displayName,
    year: v.yearOfManufacture,
    vehicle_class: v.vehicleType.vehicleClass,
    seating_capacity: v.vehicleType.seatingCap,
    city: v.city,
    image_url: v.imageUrl ?? v.vehicleType.imageUrl ?? null,
    amenities: [...new Set([...v.vehicleType.amenityTags, ...v.amenityTags])],
    verification_status: v.verificationStatus,
    is_available: v.isAvailable,
    has_verified_chauffeur: v.hasVerifiedChauffeur,
    rating: v.rating,
    review_count: v.reviewCount,
    price_indicator_paise: cheapestIndicativePaise(v.approvedTariff)?.toString() ?? null,
  };
}

export function toPublicVehicleDetail(v: PublicVehicleSource): PublicVehicleDetail {
  return {
    ...toPublicVehicleListItem(v),
    color: v.color,
    fuel_type: v.fuelType,
    air_conditioning: v.airConditioningType,
    is_vintage: v.isVintage,
    service_areas: v.serviceAreas,
    photos: v.photoUrls,
    documents_summary: v.documentCounts
      ? {
          total: v.documentCounts.total,
          verified: v.documentCounts.verified,
          expiring_soon: v.documentCounts.expiringSoon,
        }
      : { total: 0, verified: 0, expiring_soon: 0 },
    suitable_ceremonies: suitableCeremoniesForClass(v.vehicleType.vehicleClass),
  };
}
