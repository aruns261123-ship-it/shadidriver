import { Inject, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { CONFIG_TOKEN, AppConfig } from '../config/configuration';
import { BadRequestAppException, NotFoundAppException } from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';

export interface QuoteRequestInput {
  serviceCategoryId: string;
  vehicleTypeId: string;
  city?: string;
  serviceStartTime: Date;
  serviceEndTime: Date;
  routeDistanceKm?: number;
  selectedAddonIds?: string[];
  isUrgent?: boolean;
}

export interface QuoteLineItem {
  label: string;
  amount_paise: number;
  detail?: string;
}

export interface Quote {
  quote_id: string;
  expires_at: Date;
  currency: string;
  line_items: QuoteLineItem[];
  subtotal_paise: number;
  tax_paise: number;
  platform_fee_paise: number;
  total_paise: number;
  advance_token_paise: number;
  balance_paise: number;
  pricing_rule_id: string | null;
  breakdown: {
    duration_hours: number;
    is_overnight: boolean;
    base_hours: number;
    extra_hours: number;
    extra_hours_charged: number;
    distance_km: number | null;
    extra_km_charged: number;
    addons_count: number;
  };
}

/** GST rate for passenger transport (5%) — configurable via env. */
const GST_PERCENT = Number(process.env.GST_PERCENT ?? 5);
/** Platform fee (8%) — configurable via env. */
const PLATFORM_FEE_PERCENT = Number(process.env.PLATFORM_FEE_PERCENT ?? 8);
/** Quotes are valid for 15 minutes. */
const QUOTE_TTL_MINUTES = 15;
/** Urgent dispatch surcharge (25%). */
const URGENT_SURCHARGE_PERCENT = Number(process.env.URGENT_SURCHARGE_PERCENT ?? 25);

/**
 * Maps a human-readable city name to the cityCode used in pricingRule rows.
 * Case-insensitive. Falls back to 'DEL' (Delhi NCR) which is the only seeded
 * city in the development dataset. Extend this map as new cities are seeded.
 */
function resolveCityCode(city?: string): string {
  if (!city) return 'DEL';
  const c = city.trim().toUpperCase();
  if (c.includes('DELHI') || c.includes('NCR') || c.includes('NOIDA') ||
      c.includes('GURUGRAM') || c.includes('GURGAON') || c.includes('FARIDABAD') ||
      c.includes('GHAZIABAD')) {
    return 'DEL';
  }
  // Future cities — add mappings here as seeded
  // if (c.includes('MUMBAI') || c.includes('PUNE')) return 'BOM';
  return 'DEL'; // safe default
}

/**
 * Server-authoritative pricing engine (ADR-007): every rupee a customer sees
 * comes from here. The client NEVER supplies totals; booking submission
 * re-validates against the persisted quote and recalculates.
 *
 * Duration is serviceEnd − serviceStart (overnight handled naturally:
 * 8:00 PM → 7:00 AM = 11 hours). No fixed-package assumptions.
 */
@Injectable()
export class QuotesService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(CONFIG_TOKEN) private readonly config: AppConfig,
  ) {}

  async createQuote(input: QuoteRequestInput): Promise<Quote> {
    if (input.serviceEndTime <= input.serviceStartTime) {
      throw new BadRequestAppException(
        ErrorCode.INVALID_BOOKING_DRAFT,
        'Service end time must be after start time.',
      );
    }
    const durationMinutes = Math.round(
      (input.serviceEndTime.getTime() - input.serviceStartTime.getTime()) / 60_000,
    );
    if (durationMinutes < 60) {
      throw new BadRequestAppException(
        ErrorCode.INVALID_BOOKING_DRAFT,
        'Minimum service duration is 1 hour.',
      );
    }

    let vehicleType = await this.prisma.vehicleType.findUnique({
      where: { id: input.vehicleTypeId },
    });
    const isUuid = /^[0-9a-fA-F-]{36}$/.test(input.vehicleTypeId);
    if (!vehicleType && isUuid) {
      // Check if input.vehicleTypeId is a Vehicle UUID
      const vehicle = await this.prisma.vehicle.findUnique({
        where: { id: input.vehicleTypeId },
        include: { vehicleType: true },
      });
      if (vehicle) {
        vehicleType = vehicle.vehicleType;
      }
    }
    if (!vehicleType) {
      // Check if input.vehicleTypeId matches a vehicleClass string (e.g. LUXURY_SEDAN or Luxury Sedan)
      const normalizedClass = input.vehicleTypeId.toUpperCase().replace(/\s+/g, '_');
      vehicleType = await this.prisma.vehicleType.findFirst({
        where: {
          OR: [
            { vehicleClass: input.vehicleTypeId },
            { vehicleClass: normalizedClass },
            { id: { contains: normalizedClass, mode: 'insensitive' } },
          ],
          isActive: true,
        },
      });
    }
    if (!vehicleType || !vehicleType.isActive) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Vehicle type not found.');
    }

    // Resolve city string → city code (DEL is the only seeded city; extend as needed).
    const cityCode = resolveCityCode(input.city);

    const rule = await this.prisma.pricingRule.findFirst({
      where: {
        serviceCategoryId: input.serviceCategoryId,
        vehicleClass: vehicleType.vehicleClass,
        cityCode,
        isActive: true,
        effectiveFrom: { lte: new Date() },
        OR: [{ effectiveTo: null }, { effectiveTo: { gt: new Date() } }],
      },
      orderBy: { effectiveFrom: 'desc' },
    });
    if (!rule) {
      throw new NotFoundAppException(
        ErrorCode.NOT_FOUND,
        `No active pricing rule for category ${input.serviceCategoryId} / class ${vehicleType.vehicleClass}.`,
      );
    }

    const lineItems: QuoteLineItem[] = [];
    const durationHours = Math.ceil(durationMinutes / 60);
    const isOvernight =
      input.serviceEndTime.getUTCDate() !== input.serviceStartTime.getUTCDate() ||
      durationHours >= 12;

    // --- base fare (covers baseHours) ---
    const baseAmount = Number(rule.baseRatePaise);
    lineItems.push({
      label: `Base charge — ${vehicleType.displayName}`,
      amount_paise: baseAmount,
      detail: `${rule.baseHours} hrs included`,
    });

    // --- extra hours beyond base ---
    const extraHours = Math.max(0, durationHours - rule.baseHours);
    let extraHoursCharged = 0;
    if (extraHours > 0) {
      extraHoursCharged = extraHours * Number(rule.extraHourRatePaise);
      lineItems.push({
        label: 'Extra hours',
        amount_paise: extraHoursCharged,
        detail: `${extraHours} hr × ₹${(Number(rule.extraHourRatePaise) / 100).toFixed(0)}`,
      });
    }

    // --- extra distance beyond base km ---
    const distance = input.routeDistanceKm ?? 0;
    const extraKm = Math.max(0, distance - rule.baseKm);
    const extraKmCharged = Math.round(extraKm * Number(rule.extraKmRatePaise));
    if (extraKmCharged > 0) {
      lineItems.push({
        label: 'Extra distance',
        amount_paise: extraKmCharged,
        detail: `${extraKm.toFixed(1)} km × ₹${(Number(rule.extraKmRatePaise) / 100).toFixed(1)}/km`,
      });
    }

    // --- night allowance ---
    let nightCharged = 0;
    if (isOvernight && Number(rule.nightAllowancePaise) > 0) {
      nightCharged = Number(rule.nightAllowancePaise);
      lineItems.push({
        label: 'Overnight / night allowance',
        amount_paise: nightCharged,
        detail: 'Service crosses midnight or exceeds 12 hours',
      });
    }

    // --- addons (validated against DB prices) ---
    const addonIds = input.selectedAddonIds ?? [];
    let addonsTotal = 0;
    if (addonIds.length > 0) {
      const addons = await this.prisma.serviceAddon.findMany({
        where: { id: { in: addonIds }, isActive: true },
      });
      if (addons.length !== new Set(addonIds).size) {
        throw new BadRequestAppException(
          ErrorCode.VALIDATION_FAILED,
          'One or more selected addons are unavailable.',
        );
      }
      for (const addon of addons) {
        const amount = Number(addon.pricePaise);
        addonsTotal += amount;
        lineItems.push({ label: `Addon: ${addon.name}`, amount_paise: amount });
      }
    }

    let subtotal = baseAmount + extraHoursCharged + extraKmCharged + nightCharged + addonsTotal;

    // --- muhurat multiplier (peak wedding dates) ---
    const muhuratMultiplier = Number(rule.muhuratMultiplier);
    if (muhuratMultiplier > 1) {
      const surge = Math.round(subtotal * (muhuratMultiplier - 1));
      lineItems.push({
        label: 'Peak muhurat surcharge',
        amount_paise: surge,
        detail: `${muhuratMultiplier.toFixed(2)}× on base services`,
      });
      subtotal += surge;
    }

    // --- urgent dispatch surcharge ---
    if (input.isUrgent) {
      const urgent = Math.round(subtotal * (URGENT_SURCHARGE_PERCENT / 100));
      lineItems.push({
        label: 'ShadiDriver NOW urgent surcharge',
        amount_paise: urgent,
        detail: `${URGENT_SURCHARGE_PERCENT}% of subtotal`,
      });
      subtotal += urgent;
    }

    // --- platform fee + GST (on services, not on fee) ---
    const platformFee = Math.round(subtotal * (PLATFORM_FEE_PERCENT / 100));
    const tax = Math.round(subtotal * (GST_PERCENT / 100));

    const total = subtotal + platformFee + tax;

    // --- advance token per policy ---
    const policy = await this.prisma.bookingPolicy.findFirst({ where: { isDefault: true } });
    const advancePercent = policy ? Number(policy.advanceTokenPercentage) : 25;
    const advance = Math.round((total * advancePercent) / 100);

    const quote: Quote = {
      quote_id: `qt_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`,
      expires_at: new Date(Date.now() + QUOTE_TTL_MINUTES * 60_000),
      currency: 'INR',
      line_items: lineItems,
      subtotal_paise: subtotal,
      tax_paise: tax,
      platform_fee_paise: platformFee,
      total_paise: total,
      advance_token_paise: advance,
      balance_paise: total - advance,
      pricing_rule_id: rule.id,
      breakdown: {
        duration_hours: durationHours,
        is_overnight: isOvernight,
        base_hours: rule.baseHours,
        extra_hours: extraHours,
        extra_hours_charged: extraHoursCharged,
        distance_km: input.routeDistanceKm ?? null,
        extra_km_charged: extraKmCharged,
        addons_count: addonIds.length,
      },
    };
    return quote;
  }

  /**
   * Recalculates a booking's authoritative totals at submission time.
   * Used by the booking service to re-derive pricing server-side — the
   * client-supplied amounts are never trusted.
   */
  async quoteForSubmission(input: Omit<QuoteRequestInput, 'isUrgent'>) {
    return this.createQuote(input);
  }
}
