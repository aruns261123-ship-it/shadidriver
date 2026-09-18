-- =============================================================================
-- ShadiDriver Database Schema Migration: 0002_schema_extensions.sql
-- Adds tables and columns required by the NestJS API that are not in 0001_init.
-- =============================================================================

CREATE SEQUENCE IF NOT EXISTS booking_ref_seq START 100;
CREATE SEQUENCE IF NOT EXISTS group_booking_ref_seq START 100;

-- Auth session / refresh token store
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    device_id VARCHAR(120),
    fcm_token TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);

-- Idempotent mutation cache (backup to Redis)
CREATE TABLE IF NOT EXISTS idempotency_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key VARCHAR(120) NOT NULL,
    method VARCHAR(10) NOT NULL,
    path TEXT NOT NULL,
    status_code INT NOT NULL,
    response_body JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_idempotency UNIQUE (user_id, idempotency_key)
);
CREATE INDEX IF NOT EXISTS idx_idempotency_created ON idempotency_keys(created_at);

-- Configurable platform commercial / operational settings (never hard-code in app)
CREATE TABLE IF NOT EXISTS platform_settings (
    key VARCHAR(80) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Customer booking drafts (pre-submit)
CREATE TABLE IF NOT EXISTS booking_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    payload JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_booking_drafts_customer ON booking_drafts(customer_id);

DROP TRIGGER IF EXISTS trg_booking_drafts_updated_at ON booking_drafts;
CREATE TRIGGER trg_booking_drafts_updated_at
BEFORE UPDATE ON booking_drafts
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Group / convoy parent bookings
CREATE TABLE IF NOT EXISTS group_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_reference VARCHAR(30) UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(40) NOT NULL DEFAULT 'REQUESTED',
    ceremony_type VARCHAR(50) NOT NULL,
    service_start_time TIMESTAMPTZ NOT NULL,
    service_end_time TIMESTAMPTZ NOT NULL,
    city VARCHAR(50) NOT NULL,
    pickup_address TEXT NOT NULL,
    destination_address TEXT NOT NULL,
    primary_contact_name VARCHAR(120) NOT NULL,
    primary_contact_phone VARCHAR(20) NOT NULL,
    passenger_count INT NOT NULL DEFAULT 2,
    intent JSONB NOT NULL DEFAULT '{}',
    estimated_total_paise BIGINT NOT NULL DEFAULT 0,
    advance_token_paise BIGINT NOT NULL DEFAULT 0,
    idempotency_key VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS group_booking_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_booking_id UUID NOT NULL REFERENCES group_bookings(id) ON DELETE CASCADE,
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    vehicle_id UUID REFERENCES vehicles(id),
    driver_id UUID REFERENCES drivers(id),
    model_name VARCHAR(100),
    quantity INT DEFAULT 1,
    estimated_total_paise BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Support tickets (MVP optional / Phase 2 table used by Flutter SupportRepository)
CREATE TABLE IF NOT EXISTS support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id),
    reported_by_user_id UUID NOT NULL REFERENCES users(id),
    category VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(30) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'CLOSED')),
    assigned_admin_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

DROP TRIGGER IF EXISTS trg_support_tickets_updated_at ON support_tickets;
CREATE TRIGGER trg_support_tickets_updated_at
BEFORE UPDATE ON support_tickets
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Pre-trip checklists
CREATE TABLE IF NOT EXISTS pre_trip_checklists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES drivers(id),
    is_fuel_checked BOOLEAN NOT NULL DEFAULT FALSE,
    is_dual_ac_checked BOOLEAN NOT NULL DEFAULT FALSE,
    is_grooming_checked BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Extra driver profile fields used by Flutter DriverProfile
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '';
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS operating_area VARCHAR(120) DEFAULT '';
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS wedding_experience_years INT DEFAULT 0;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS document_status VARCHAR(40) DEFAULT 'PENDING_SUBMISSION';
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS vehicle_status VARCHAR(80) DEFAULT '';

-- Extra customer profile fields
ALTER TABLE customers ADD COLUMN IF NOT EXISTS city VARCHAR(50) DEFAULT '';
ALTER TABLE customers ADD COLUMN IF NOT EXISTS wedding_preferences TEXT;

-- Extra vehicle catalog fields
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS amenities JSONB DEFAULT '[]';
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS gallery_urls JSONB DEFAULT '[]';
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS transmission VARCHAR(20) DEFAULT 'AUTOMATIC';
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS suitability_info TEXT DEFAULT '';
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS suitable_ceremonies JSONB DEFAULT '[]';

-- Saved address type for Flutter AddressType enum
ALTER TABLE saved_addresses ADD COLUMN IF NOT EXISTS address_type VARCHAR(30) DEFAULT 'other';

-- Service addon extra fields
ALTER TABLE service_addons ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '[]';
ALTER TABLE service_addons ADD COLUMN IF NOT EXISTS asset_path TEXT;

ALTER TABLE service_categories ADD COLUMN IF NOT EXISTS icon_url TEXT;
ALTER TABLE service_categories ADD COLUMN IF NOT EXISTS asset_path TEXT;

-- Booking extras for cancellation, OTP rotation, emergency
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS decline_reason VARCHAR(40);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS decline_notes TEXT;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS emergency_reason TEXT;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS previous_driver_id UUID REFERENCES drivers(id);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS city_code VARCHAR(10);

-- Widen status check if 0001 was already applied with the narrower set
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE bookings ADD CONSTRAINT bookings_status_check CHECK (status IN (
    'DRAFT',
    'REQUESTED',
    'DRIVER_ACCEPTED',
    'REJECTED',
    'EXPIRED',
    'PAYMENT_PENDING',
    'PAYMENT_FAILED',
    'CONFIRMED',
    'DRIVER_ASSIGNED',
    'DRIVER_ARRIVING',
    'EN_ROUTE',
    'ARRIVED',
    'TRIP_STARTED',
    'IN_PROGRESS',
    'EMERGENCY_REPLACEMENT',
    'COMPLETED',
    'CANCELLED'
));

-- Optional auth.uid() stub so RLS policies do not explode on vanilla Postgres
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION auth.jwt() RETURNS JSONB AS $$
    SELECT COALESCE(current_setting('request.jwt.claims', true)::jsonb, '{}'::jsonb);
$$ LANGUAGE sql STABLE;
