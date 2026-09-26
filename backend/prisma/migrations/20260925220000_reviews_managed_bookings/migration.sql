-- Reviews for the managed-booking model.
--
-- Managed (group) bookings never create rows in `bookings` — the parent IS the
-- group booking — so `reviews.booking_id` (previously NOT NULL) must become
-- nullable, and eligibility must key off the GROUP booking instead.
--
-- One review per vehicle per group booking: a customer rates each car they
-- actually received, not one blob for the whole convoy.
--
-- Data preserving: existing single-booking reviews keep their booking_id.

ALTER TABLE "reviews" ALTER COLUMN "booking_id" DROP NOT NULL;
ALTER TABLE "reviews" DROP CONSTRAINT IF EXISTS "reviews_booking_id_key";
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_group_booking_vehicle_unique"
    UNIQUE ("group_booking_id", "vehicle_id");
CREATE INDEX IF NOT EXISTS "reviews_group_booking_id_idx" ON "reviews"("group_booking_id");
