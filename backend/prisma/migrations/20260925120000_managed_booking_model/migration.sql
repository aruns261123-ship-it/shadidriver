-- CreateEnum
CREATE TYPE "AssignmentStatus" AS ENUM ('PROPOSED', 'VEHICLE_CONFIRMED', 'CHAUFFEUR_ASSIGNED', 'CHAUFFEUR_ACCEPTED', 'CHAUFFEUR_DECLINED', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "VehicleVerificationStatus" AS ENUM ('PENDING', 'VERIFIED', 'CHANGES_REQUIRED', 'REJECTED', 'SUSPENDED', 'DOCUMENT_EXPIRED');

-- CreateEnum
CREATE TYPE "PricingStatus" AS ENUM ('PENDING_REVIEW', 'APPROVED', 'REJECTED', 'SUPERSEDED', 'ACTIVE');

-- CreateEnum
CREATE TYPE "ReviewStatus" AS ENUM ('PENDING_MODERATION', 'PUBLISHED', 'HIDDEN');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "BookingStatus" ADD VALUE 'UNDER_REVIEW';
ALTER TYPE "BookingStatus" ADD VALUE 'VEHICLE_OPTIONS_PREPARED';
ALTER TYPE "BookingStatus" ADD VALUE 'CUSTOMER_CONFIRMATION_PENDING';
ALTER TYPE "BookingStatus" ADD VALUE 'EXPIRED';
ALTER TYPE "BookingStatus" ADD VALUE 'PAYMENT_PENDING';
ALTER TYPE "BookingStatus" ADD VALUE 'PAYMENT_FAILED';

-- DropForeignKey
ALTER TABLE "reviews" DROP CONSTRAINT "reviews_driver_id_fkey";

-- DropForeignKey
ALTER TABLE "vehicle_assignments" DROP CONSTRAINT "vehicle_assignments_driver_id_fkey";

-- DropIndex
DROP INDEX "vehicle_assignments_driver_id_status_idx";

-- DropIndex
DROP INDEX "vehicle_assignments_vehicle_id_idx";

-- AlterTable
ALTER TABLE "group_bookings" ADD COLUMN     "communication_preference" VARCHAR(30) NOT NULL DEFAULT 'PHONE',
ADD COLUMN     "pricing_snapshot" JSONB,
ADD COLUMN     "requested_fleet_items" JSONB NOT NULL DEFAULT '[]',
ADD COLUMN     "requirements" JSONB DEFAULT '[]';

-- AlterTable
ALTER TABLE "reviews" ADD COLUMN     "assignment_id" UUID,
ADD COLUMN     "group_booking_id" UUID,
ADD COLUMN     "moderated_at" TIMESTAMPTZ(6),
ADD COLUMN     "moderated_by_user_id" UUID,
ADD COLUMN     "moderation_reason" TEXT,
ADD COLUMN     "status" "ReviewStatus" NOT NULL DEFAULT 'PENDING_MODERATION',
ADD COLUMN     "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "vehicle_quality_rating" INTEGER,
ALTER COLUMN "driver_id" DROP NOT NULL;

-- AlterTable
-- vehicle_assignments.status was typed BookingStatus and modelled the old
-- driver-offer loop. It becomes AssignmentStatus. The column is added first,
-- back-filled from the legacy value, and only then dropped, so this migration
-- is data-preserving on a non-empty database.
ALTER TABLE "vehicle_assignments"
ADD COLUMN     "assigned_at" TIMESTAMPTZ(6),
ADD COLUMN     "assigned_by_user_id" UUID,
ADD COLUMN     "assignment_status" "AssignmentStatus" NOT NULL DEFAULT 'PROPOSED',
ADD COLUMN     "pricing_snapshot" JSONB,
ALTER COLUMN "driver_id" DROP NOT NULL;

UPDATE "vehicle_assignments"
SET "assignment_status" = CASE "status"::text
  WHEN 'DRAFT'             THEN 'PROPOSED'
  WHEN 'REQUESTED'         THEN 'PROPOSED'
  WHEN 'DRIVER_ACCEPTED'   THEN 'CHAUFFEUR_ACCEPTED'
  WHEN 'CONFIRMED'         THEN 'VEHICLE_CONFIRMED'
  WHEN 'EN_ROUTE'          THEN 'EN_ROUTE'
  WHEN 'ARRIVED'           THEN 'ARRIVED'
  WHEN 'IN_PROGRESS'       THEN 'IN_PROGRESS'
  WHEN 'COMPLETED'         THEN 'COMPLETED'
  WHEN 'CANCELLED'         THEN 'CANCELLED'
  ELSE 'PROPOSED'
END::"AssignmentStatus";

ALTER TABLE "vehicle_assignments" DROP COLUMN "status";

-- CreateTable
CREATE TABLE "favorite_vehicles" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "customer_id" UUID NOT NULL,
    "vehicle_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "favorite_vehicles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicle_pricing" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "vehicle_id" UUID NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "currency" VARCHAR(5) NOT NULL DEFAULT 'INR',
    "local_included_km" INTEGER,
    "local_amount_paise" BIGINT,
    "per_km_paise" BIGINT,
    "hourly_paise" BIGINT,
    "extra_hour_paise" BIGINT,
    "full_day_paise" BIGINT,
    "overnight_paise" BIGINT,
    "outstation_per_day_paise" BIGINT,
    "outstation_per_km_paise" BIGINT,
    "status" "PricingStatus" NOT NULL DEFAULT 'PENDING_REVIEW',
    "submitted_by_user_id" UUID NOT NULL,
    "submitted_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewed_by_user_id" UUID,
    "reviewed_at" TIMESTAMPTZ(6),
    "decision_reason" TEXT,
    "effective_from" TIMESTAMPTZ(6),
    "effective_to" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vehicle_pricing_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "operations_notes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "group_booking_id" UUID,
    "booking_id" UUID,
    "author_user_id" UUID NOT NULL,
    "body" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "operations_notes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "favorite_vehicles_customer_id_idx" ON "favorite_vehicles"("customer_id");

-- CreateIndex
CREATE UNIQUE INDEX "favorite_vehicles_customer_id_vehicle_id_key" ON "favorite_vehicles"("customer_id", "vehicle_id");

-- CreateIndex
CREATE INDEX "vehicle_pricing_status_idx" ON "vehicle_pricing"("status");

-- CreateIndex
CREATE UNIQUE INDEX "vehicle_pricing_vehicle_id_version_key" ON "vehicle_pricing"("vehicle_id", "version");

-- CreateIndex
CREATE INDEX "operations_notes_group_booking_id_idx" ON "operations_notes"("group_booking_id");

-- CreateIndex
CREATE INDEX "operations_notes_booking_id_idx" ON "operations_notes"("booking_id");

-- CreateIndex
CREATE UNIQUE INDEX "reviews_assignment_id_key" ON "reviews"("assignment_id");

-- CreateIndex
CREATE INDEX "reviews_vehicle_id_status_idx" ON "reviews"("vehicle_id", "status");

-- CreateIndex
CREATE INDEX "reviews_status_idx" ON "reviews"("status");

-- CreateIndex
CREATE INDEX "vehicle_assignments_driver_id_assignment_status_idx" ON "vehicle_assignments"("driver_id", "assignment_status");

-- CreateIndex
CREATE INDEX "vehicle_assignments_vehicle_id_assignment_status_idx" ON "vehicle_assignments"("vehicle_id", "assignment_status");

-- AddForeignKey
ALTER TABLE "vehicle_assignments" ADD CONSTRAINT "vehicle_assignments_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "drivers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "favorite_vehicles" ADD CONSTRAINT "favorite_vehicles_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "favorite_vehicles" ADD CONSTRAINT "favorite_vehicles_vehicle_id_fkey" FOREIGN KEY ("vehicle_id") REFERENCES "vehicles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vehicle_pricing" ADD CONSTRAINT "vehicle_pricing_vehicle_id_fkey" FOREIGN KEY ("vehicle_id") REFERENCES "vehicles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "operations_notes" ADD CONSTRAINT "operations_notes_author_user_id_fkey" FOREIGN KEY ("author_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "operations_notes" ADD CONSTRAINT "operations_notes_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "operations_notes" ADD CONSTRAINT "operations_notes_group_booking_id_fkey" FOREIGN KEY ("group_booking_id") REFERENCES "group_bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_group_booking_id_fkey" FOREIGN KEY ("group_booking_id") REFERENCES "group_bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_assignment_id_fkey" FOREIGN KEY ("assignment_id") REFERENCES "vehicle_assignments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "drivers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

