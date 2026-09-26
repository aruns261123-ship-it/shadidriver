-- Trip lifecycle for managed (group) bookings.
--
-- A confirmed booking must be EXECUTABLE: the assigned chauffeur moves the
-- duty through en-route → arrived → in-service (customer OTP) → completed.
-- This mirrors the single-booking path, which already stores a hashed trip
-- start OTP on `bookings.start_otp_hash`.
ALTER TABLE "group_bookings" ADD COLUMN "start_otp_hash" VARCHAR(64);
