import { config } from '../config.js';
import { AppError, HttpStatus } from '../errors.js';
import { store } from '../store/memory-store.js';
import { cityToCode, hoursBetween, isNightWindow, roundPaise } from '../utils/geo.js';

function defaultPolicy() {
  return [...store.policies.values()].find((p) => p.isDefault) || [...store.policies.values()][0];
}

export function quote(input) {
  const cityCode = (input.cityCode || cityToCode(input.city || 'Delhi')).toUpperCase();
  const durationHours = hoursBetween(input.eventStartTime, input.eventEndTime);
  const rules = [...store.pricingRules.values()].filter(
    (r) =>
      r.isActive &&
      r.cityCode === cityCode &&
      r.vehicleClass === input.vehicleClass &&
      (r.serviceCategoryId === input.serviceCategoryId || !r.serviceCategoryId),
  );
  rules.sort((a, b) => (a.serviceCategoryId === input.serviceCategoryId ? -1 : 1));
  const rule = rules[0];
  if (!rule) {
    throw new AppError(
      'PRICING_RULE_NOT_FOUND',
      'No active pricing rule for this city, vehicle class, and ceremony.',
      HttpStatus.UNPROCESSABLE,
      { cityCode, vehicleClass: input.vehicleClass, serviceCategoryId: input.serviceCategoryId },
    );
  }

  const policy = defaultPolicy();
  const addonFarePaise = (input.selectedAddonIds || []).reduce((sum, id) => {
    const addon = store.addons.get(id);
    return addon && addon.isActive ? sum + addon.pricePaise : sum;
  }, 0);

  const extraHours = Math.max(0, durationHours - rule.baseHours);
  const extraKm = Math.max(0, (input.routeDistanceKm ?? 0) - rule.baseKm);
  let subtotal = rule.baseRatePaise + extraHours * rule.extraHourRatePaise + extraKm * rule.extraKmRatePaise;
  const night = isNightWindow(input.eventStartTime) ? rule.nightAllowancePaise : 0;
  subtotal += night;
  subtotal = roundPaise(subtotal * rule.muhuratMultiplier);
  subtotal += addonFarePaise;

  const gstRate = config.settings.gstRate;
  const taxPaise = roundPaise(subtotal * gstRate);
  const totalPaise = subtotal + taxPaise;
  const tokenPercentage = policy.advanceTokenPercentage;
  const advanceTokenPaise = roundPaise((totalPaise * tokenPercentage) / 100);

  return {
    pricingRuleId: rule.id,
    bookingPolicyId: policy.id,
    serviceCategoryId: input.serviceCategoryId,
    vehicleClass: rule.vehicleClass,
    cityCode,
    durationHours,
    baseHours: rule.baseHours,
    baseKm: rule.baseKm,
    baseRatePaise: rule.baseRatePaise,
    extraHourPaise: extraHours * rule.extraHourRatePaise,
    extraKmPaise: extraKm * rule.extraKmRatePaise,
    nightAllowancePaise: night,
    muhuratMultiplier: rule.muhuratMultiplier,
    addonFarePaise,
    subtotalPaise: subtotal,
    taxPaise,
    discountPaise: 0,
    totalPaise,
    totalCents: totalPaise,
    advanceTokenPaise,
    advanceTokenCents: advanceTokenPaise,
    advanceTokenLabel: `${tokenPercentage}% Advance Token`,
    tokenPercentage,
    gstRate,
  };
}

export function driverEarnings(totalPaise) {
  return roundPaise(totalPaise * (1 - config.settings.platformCommissionRate));
}

export const pricingService = { quote, driverEarnings };
