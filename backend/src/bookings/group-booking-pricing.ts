/**
 * Server-authoritative quote derivation for group bookings.
 *
 * The customer-visible price is NEVER computed on the client and never read
 * from a legacy column. It is derived here from the vehicle's newest APPROVED
 * tariff version, and the derivation is frozen into an immutable snapshot on
 * the assignment so a later tariff edit cannot rewrite an agreed price.
 *
 * Deliberately conservative: when the tariff has nothing applicable, the line
 * has NO price (null) instead of a fabricated 0.
 */

/** The subset of a tariff version this derivation needs. */
export interface QuoteTariff {
  id?: string;
  version?: number;
  localIncludedKm: number | null;
  localAmountPaise: bigint | null;
  perKmPaise: bigint | null;
  hourlyPaise: bigint | null;
  extraHourPaise: bigint | null;
  fullDayPaise: bigint | null;
  overnightPaise: bigint | null;
  outstationPerDayPaise: bigint | null;
  outstationPerKmPaise: bigint | null;
}

export interface LineQuote {
  /** null when the tariff has no applicable component — never 0-by-default. */
  amountPaise: bigint | null;
  /** Which tariff component produced the amount (auditable). */
  basis:
    | 'OVERNIGHT'
    | 'FULL_DAY'
    | 'HOURLY'
    | 'LOCAL_PACKAGE'
    | 'UNPRICED';
  /** Billable hours used for an HOURLY basis. */
  billableHours?: number;
  includedKm?: number | null;
  perKmPaise?: bigint | null;
  /** Tariff version this line was quoted from. */
  tariffVersion?: number;
  tariffId?: string;
}

/**
 * Full-day / overnight / hourly / local-package selection.
 *
 * Rules (documented so operations can reason about a quote):
 *   * a window crossing midnight, or covering 12h+, is an OVERNIGHT job;
 *   * a window covering 8h+ is a FULL_DAY job;
 *   * a shorter window bills HOURLY when an hourly rate exists, else falls
 *     back to the local package;
 *   * anything else is UNPRICED (surfaced as "on request", never ₹0).
 *
 * Outstation rates are intentionally NOT auto-selected: they depend on a
 * declared route distance, which operations enters when re-quoting.
 */
export function deriveLineQuote(
  tariff: QuoteTariff | null,
  hours: number,
  crossesMidnight: boolean,
): LineQuote {
  if (!tariff) {
    return { amountPaise: null, basis: 'UNPRICED' };
  }

  const meta = { tariffVersion: tariff.version, tariffId: tariff.id };

  if ((crossesMidnight || hours >= 12) && tariff.overnightPaise != null) {
    return { amountPaise: tariff.overnightPaise, basis: 'OVERNIGHT', ...meta };
  }
  if (hours >= 8) {
    if (tariff.fullDayPaise != null) {
      return { amountPaise: tariff.fullDayPaise, basis: 'FULL_DAY', ...meta };
    }
    if (tariff.overnightPaise != null) {
      return { amountPaise: tariff.overnightPaise, basis: 'OVERNIGHT', ...meta };
    }
  }
  const billableHours = Math.max(1, Math.ceil(hours));
  if (tariff.hourlyPaise != null) {
    return {
      amountPaise: tariff.hourlyPaise * BigInt(billableHours),
      basis: 'HOURLY',
      billableHours,
      ...meta,
    };
  }
  if (tariff.localAmountPaise != null) {
    return {
      amountPaise: tariff.localAmountPaise,
      basis: 'LOCAL_PACKAGE',
      includedKm: tariff.localIncludedKm,
      perKmPaise: tariff.perKmPaise,
      ...meta,
    };
  }
  if (tariff.fullDayPaise != null) {
    return { amountPaise: tariff.fullDayPaise, basis: 'FULL_DAY', ...meta };
  }
  return { amountPaise: null, basis: 'UNPRICED', ...meta };
}

/** Fraction of the total taken as the advance token (25%, rounded down). */
export const ADVANCE_FRACTION = 25n;
export const ADVANCE_DENOMINATOR = 100n;

export function advanceFor(amountPaise: bigint): bigint {
  return (amountPaise * ADVANCE_FRACTION) / ADVANCE_DENOMINATOR;
}

export function serviceHours(start: Date, end: Date): number {
  return (end.getTime() - start.getTime()) / 3_600_000;
}

/** True when the service window spans two calendar days in local time. */
export function crossesMidnight(start: Date, end: Date): boolean {
  return start.getUTCDate() !== end.getUTCDate() || start.getUTCMonth() !== end.getUTCMonth();
}
