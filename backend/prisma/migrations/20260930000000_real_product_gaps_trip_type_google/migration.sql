-- Real-product gaps: trip direction persistence + Google customer identity.
-- 1) bookings / group_bookings: persist the customer-chosen trip direction
--    (ONE_WAY | ROUND_TRIP). Billable distance is derived SERVER-side
--    (ROUND_TRIP = one-way route × 2) — the column records the choice, the
--    pricing engine owns the arithmetic.
-- 2) users: Google identity for the real Google sign-in flow. google_id is
--    the immutable Google `sub` claim (unique); auth_provider records the
--    creation/link path. Existing rows are untouched (PHONE default).

ALTER TABLE "bookings"
  ADD COLUMN "trip_type" VARCHAR(20) NOT NULL DEFAULT 'ONE_WAY';

ALTER TABLE "group_bookings"
  ADD COLUMN "trip_type" VARCHAR(20) NOT NULL DEFAULT 'ONE_WAY';

CREATE TYPE "AuthProvider" AS ENUM ('PHONE', 'GOOGLE');

ALTER TABLE "users"
  ADD COLUMN "google_id" VARCHAR(64),
  ADD COLUMN "auth_provider" "AuthProvider" NOT NULL DEFAULT 'PHONE';

CREATE UNIQUE INDEX "users_google_id_key" ON "users"("google_id");
