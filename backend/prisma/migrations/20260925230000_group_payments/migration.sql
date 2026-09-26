-- Payments on the managed (group) booking path.
--
-- The payments table is keyed on `bookings` (NOT NULL), but managed bookings
-- never create rows there — the parent IS the group booking. Payments must be
-- attachable to the GROUP booking instead.
--
-- Data preserving: legacy single-booking payments keep their booking_id.

ALTER TABLE "payments" ALTER COLUMN "booking_id" DROP NOT NULL;
ALTER TABLE "payments" ADD COLUMN "group_booking_id" UUID;
ALTER TABLE "payments"
    ADD CONSTRAINT "payments_group_booking_id_fkey"
    FOREIGN KEY ("group_booking_id") REFERENCES "group_bookings"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX "payments_group_booking_id_idx" ON "payments"("group_booking_id");

-- Track WHEN each settlement stage completed on the group booking itself, so
-- the trip gate and the ops queue can ask "is the money settled?" without
-- joining the payments table.
ALTER TABLE "group_bookings" ADD COLUMN "advance_paid_at" TIMESTAMPTZ(6);
ALTER TABLE "group_bookings" ADD COLUMN "balance_paid_at" TIMESTAMPTZ(6);
