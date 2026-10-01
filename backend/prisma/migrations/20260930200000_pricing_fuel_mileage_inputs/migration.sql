-- Real-product closeout: formula-driven distance pricing inputs.
-- The partner provides fuel price (₹/litre) and mileage (km/litre); the
-- per-km customer rate is DERIVED server-side:
--   ratePerKm = fuelPricePerLitre / mileageKmPerLitre + 10
-- so a partner can never hand-enter the customer-facing rate.

ALTER TABLE "vehicle_pricing"
  ADD COLUMN "fuel_price_per_litre" DOUBLE PRECISION,
  ADD COLUMN "mileage_km_per_litre" DOUBLE PRECISION;
