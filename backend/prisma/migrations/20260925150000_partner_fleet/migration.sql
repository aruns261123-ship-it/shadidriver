-- CreateEnum
CREATE TYPE "PartnerDocumentType" AS ENUM ('PARTNER_IDENTITY', 'DRIVING_LICENCE', 'TRADE_LICENSE', 'POLICE_VERIFICATION', 'GST_CERTIFICATE', 'BANK_PROOF');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "VerificationStatus" ADD VALUE 'REJECTED';
ALTER TYPE "VerificationStatus" ADD VALUE 'DOCUMENT_EXPIRED';

-- AlterTable
-- The partner verification column moves from a free-text VARCHAR(30) to the
-- shared VerificationStatus enum. The new column is added, back-filled from the
-- legacy text value, and only then is the old column dropped, so this migration
-- is data-preserving. The back-fill references only PRE-EXISTING enum labels
-- (the two values added above are not used here, which PostgreSQL requires
-- inside a transaction).
ALTER TABLE "fleet_owners" RENAME COLUMN "verification_status" TO "verification_status_legacy";

ALTER TABLE "fleet_owners" ADD COLUMN     "base_city" VARCHAR(50),
ADD COLUMN     "contact_name" VARCHAR(150),
ADD COLUMN     "decision_reason" TEXT,
ADD COLUMN     "emergency_contact_name" VARCHAR(150),
ADD COLUMN     "emergency_contact_phone" VARCHAR(20),
ADD COLUMN     "experience_years" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "languages_spoken" TEXT[] DEFAULT ARRAY['Hindi']::TEXT[],
ADD COLUMN     "license_number" VARCHAR(50),
ADD COLUMN     "reviewed_at" TIMESTAMPTZ(6),
ADD COLUMN     "service_cities" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "submitted_at" TIMESTAMPTZ(6),
ADD COLUMN     "verification_status" "VerificationStatus" NOT NULL DEFAULT 'PENDING_SUBMISSION';

UPDATE "fleet_owners"
SET "verification_status" = CASE upper("verification_status_legacy")::text
  WHEN 'APPROVED'       THEN 'APPROVED'::"VerificationStatus"
  WHEN 'SUBMITTED'      THEN 'SUBMITTED'::"VerificationStatus"
  WHEN 'UNDER_REVIEW'   THEN 'UNDER_REVIEW'::"VerificationStatus"
  WHEN 'ACTION_REQUIRED' THEN 'ACTION_REQUIRED'::"VerificationStatus"
  WHEN 'SUSPENDED'      THEN 'SUSPENDED'::"VerificationStatus"
  ELSE 'PENDING_SUBMISSION'::"VerificationStatus"
END;

ALTER TABLE "fleet_owners" DROP COLUMN "verification_status_legacy";

-- AlterTable
ALTER TABLE "vehicles" ADD COLUMN     "transmission" VARCHAR(20) NOT NULL DEFAULT 'AUTOMATIC';

-- DropEnum
DROP TYPE "VehicleVerificationStatus";

-- CreateTable
CREATE TABLE "partner_documents" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "partner_id" UUID NOT NULL,
    "document_type" "PartnerDocumentType" NOT NULL,
    "document_number" VARCHAR(100),
    "storage_path" TEXT NOT NULL,
    "mime_type" VARCHAR(50) NOT NULL,
    "issued_date" DATE,
    "expiry_date" DATE,
    "verification_status" "DocumentReviewStatus" NOT NULL DEFAULT 'PENDING_REVIEW',
    "rejection_reason" TEXT,
    "verified_by" UUID,
    "verified_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "partner_documents_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "partner_documents_expiry_date_idx" ON "partner_documents"("expiry_date");

-- CreateIndex
CREATE UNIQUE INDEX "partner_documents_partner_id_document_type_key" ON "partner_documents"("partner_id", "document_type");

-- AddForeignKey
ALTER TABLE "partner_documents" ADD CONSTRAINT "partner_documents_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "fleet_owners"("id") ON DELETE CASCADE ON UPDATE CASCADE;

