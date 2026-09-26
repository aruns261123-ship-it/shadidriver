-- Slice: operations booking workspace.
--
-- Two additive, data-preserving changes:
--   1. group_booking_events — the audit trail for the managed-bookings
--      lifecycle (mirrors booking_events, which only covers single bookings).
--   2. estimated_total_paise / advance_token_paise become NULLABLE on group
--      bookings and assignments. A request whose vehicles carry no APPROVED
--      tariff has no price yet; storing 0 there made the app advertise "₹0"
--      for a booking that was never quoted. NULL means exactly "not priced".

CREATE TABLE "group_booking_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "group_booking_id" UUID NOT NULL,
    "from_status" VARCHAR(40) NOT NULL,
    "to_status" VARCHAR(40) NOT NULL,
    "action" VARCHAR(60) NOT NULL,
    "triggered_by_user_id" UUID NOT NULL,
    "trigger_role" VARCHAR(30) NOT NULL,
    "event_reason" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "group_booking_events_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "group_booking_events"
    ADD CONSTRAINT "group_booking_events_group_booking_id_fkey"
    FOREIGN KEY ("group_booking_id") REFERENCES "group_bookings"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "group_booking_events"
    ADD CONSTRAINT "group_booking_events_triggered_by_user_id_fkey"
    FOREIGN KEY ("triggered_by_user_id") REFERENCES "users"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE INDEX "group_booking_events_group_booking_id_created_at_idx"
    ON "group_booking_events"("group_booking_id", "created_at");

-- Existing rows keep their values; only the NOT NULL constraint is dropped.
ALTER TABLE "group_bookings" ALTER COLUMN "estimated_total_paise" DROP NOT NULL;
ALTER TABLE "group_bookings" ALTER COLUMN "advance_token_paise" DROP NOT NULL;
ALTER TABLE "vehicle_assignments" ALTER COLUMN "estimated_total_paise" DROP NOT NULL;
ALTER TABLE "vehicle_assignments" ALTER COLUMN "advance_token_paise" DROP NOT NULL;
