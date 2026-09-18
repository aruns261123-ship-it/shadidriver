-- =============================================================================
-- ShadiDriver Database Schema Migration: 0001_init.sql
-- Engine: PostgreSQL 16+ with PostGIS & pgcrypto
-- Description: Consolidated production database schema for ShadiDriver,
--              including core actors, KYC verification, vehicle registry,
--              state machine, pricing rules, availabilities, financials,
--              audit logging, and Row-Level Security (RLS) policies.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Required Extensions
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- 2. Utility Functions & Triggers
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- 3. Core Actors & Identity
-- -----------------------------------------------------------------------------

-- 3.1 Central Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(15) UNIQUE NOT NULL, -- E.164 format (+91...)
    country_code VARCHAR(5) DEFAULT '+91',
    email VARCHAR(255) UNIQUE,
    full_name VARCHAR(150),
    avatar_url TEXT,
    primary_role VARCHAR(30) NOT NULL CHECK (primary_role IN (
        'customer',
        'driver',
        'operationsAdmin',
        'verificationAdmin',
        'financeAdmin',
        'superAdmin',
        'fleetOwner'
    )),
    account_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE' CHECK (account_status IN (
        'ACTIVE',
        'SUSPENDED',
        'PENDING_VERIFICATION',
        'PROFILE_INCOMPLETE'
    )),
    is_active BOOLEAN DEFAULT TRUE,
    is_phone_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone_number);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(primary_role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(account_status);

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3.2 Customers Profile
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    emergency_contact_name VARCHAR(150),
    emergency_contact_phone VARCHAR(20),
    billing_address JSONB,
    gstin VARCHAR(15),
    preferred_language VARCHAR(20) DEFAULT 'en',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

DROP TRIGGER IF EXISTS trg_customers_updated_at ON customers;
CREATE TRIGGER trg_customers_updated_at
BEFORE UPDATE ON customers
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3.3 Fleet Owners (Agencies & Multi-vehicle partners)
CREATE TABLE IF NOT EXISTS fleet_owners (
    id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(200) NOT NULL,
    trade_license_number VARCHAR(100),
    pan_number VARCHAR(10),
    gstin VARCHAR(15),
    bank_account_details JSONB,
    verification_status VARCHAR(30) DEFAULT 'PENDING' CHECK (verification_status IN (
        'PENDING', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'SUSPENDED'
    )),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

DROP TRIGGER IF EXISTS trg_fleet_owners_updated_at ON fleet_owners;
CREATE TRIGGER trg_fleet_owners_updated_at
BEFORE UPDATE ON fleet_owners
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3.4 Professional Chauffeurs / Drivers
CREATE TABLE IF NOT EXISTS drivers (
    id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    fleet_owner_id UUID REFERENCES fleet_owners(id) ON DELETE SET NULL,
    date_of_birth DATE,
    experience_years INT NOT NULL DEFAULT 0 CHECK (experience_years >= 0),
    license_number VARCHAR(50) UNIQUE,
    languages_spoken TEXT[] DEFAULT '{"Hindi"}',
    ceremonial_attire_sizes JSONB, -- { "suit": "40R", "safa": "L", "height_cm": 178 }
    duty_status VARCHAR(20) DEFAULT 'OFFLINE' CHECK (duty_status IN (
        'AVAILABLE', 'BUSY', 'OFFLINE', 'AVAILABLE_NOW'
    )),
    verification_status VARCHAR(30) DEFAULT 'PENDING_SUBMISSION' CHECK (verification_status IN (
        'PENDING_SUBMISSION', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'ACTION_REQUIRED', 'SUSPENDED'
    )),
    police_clearance_status VARCHAR(30) DEFAULT 'PENDING',
    ceremonial_attire_status VARCHAR(30) DEFAULT 'PENDING',
    is_online BOOLEAN DEFAULT FALSE,
    current_location GEOGRAPHY(POINT, 4326),
    last_location_update TIMESTAMPTZ,
    average_rating NUMERIC(3, 2) DEFAULT 5.00,
    total_trips_completed INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_drivers_duty ON drivers(duty_status);
CREATE INDEX IF NOT EXISTS idx_drivers_status ON drivers(verification_status);
CREATE INDEX IF NOT EXISTS idx_drivers_geo ON drivers USING GIST(current_location);

DROP TRIGGER IF EXISTS trg_drivers_updated_at ON drivers;
CREATE TRIGGER trg_drivers_updated_at
BEFORE UPDATE ON drivers
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- 4. Vehicles & Fleet
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fleet_code VARCHAR(30) UNIQUE NOT NULL,
    independent_driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
    fleet_owner_id UUID REFERENCES fleet_owners(id) ON DELETE SET NULL,
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year_of_manufacture INT NOT NULL,
    color VARCHAR(30) NOT NULL,
    registration_number VARCHAR(30) UNIQUE NOT NULL,
    seating_capacity INT NOT NULL DEFAULT 4,
    fuel_type VARCHAR(20) NOT NULL,
    vehicle_class VARCHAR(40) NOT NULL, -- LUXURY_SEDAN, ULTRA_LUXURY, VINTAGE, EXECUTIVE_MPV
    is_vintage BOOLEAN DEFAULT FALSE,
    air_conditioning_type VARCHAR(30) DEFAULT 'DUAL_CLIMATE_CONTROL',
    base_price_paise BIGINT NOT NULL DEFAULT 0,
    city VARCHAR(50) NOT NULL,
    image_url TEXT,
    verification_status VARCHAR(30) DEFAULT 'PENDING_SUBMISSION' CHECK (verification_status IN (
        'PENDING_SUBMISSION', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'ACTION_REQUIRED', 'SUSPENDED'
    )),
    is_available BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_vehicles_class ON vehicles(vehicle_class);
CREATE INDEX IF NOT EXISTS idx_vehicles_status ON vehicles(verification_status);
CREATE INDEX IF NOT EXISTS idx_vehicles_city ON vehicles(city);

DROP TRIGGER IF EXISTS trg_vehicles_updated_at ON vehicles;
CREATE TRIGGER trg_vehicles_updated_at
BEFORE UPDATE ON vehicles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Fleet Agency Vehicle Junction
CREATE TABLE IF NOT EXISTS fleet_vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fleet_owner_id UUID NOT NULL REFERENCES fleet_owners(id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    assigned_driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
    status VARCHAR(30) DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_fleet_vehicle UNIQUE (fleet_owner_id, vehicle_id)
);

-- -----------------------------------------------------------------------------
-- 5. KYC Documents & Compliance Audit
-- -----------------------------------------------------------------------------

-- 5.1 Driver Compliance Documents
CREATE TABLE IF NOT EXISTS driver_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN (
        'DRIVING_LICENCE',
        'AADHAAR_MASKED',
        'POLICE_VERIFICATION',
        'CHAUFFEUR_CERTIFICATE',
        'MEDICAL_FITNESS',
        'BACKGROUND_CHECK'
    )),
    document_number VARCHAR(100),
    storage_path TEXT NOT NULL, -- Private Cloudflare R2 / S3 object key
    mime_type VARCHAR(50) NOT NULL,
    issued_date DATE,
    expiry_date DATE,
    verification_status VARCHAR(30) DEFAULT 'PENDING_REVIEW' CHECK (verification_status IN (
        'PENDING_REVIEW', 'VERIFIED', 'REJECTED', 'ACTION_REQUIRED', 'EXPIRED'
    )),
    rejection_reason TEXT,
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_driver_doc UNIQUE(driver_id, document_type)
);
CREATE INDEX IF NOT EXISTS idx_driver_docs_expiry ON driver_documents(expiry_date);
CREATE INDEX IF NOT EXISTS idx_driver_docs_status ON driver_documents(verification_status);

DROP TRIGGER IF EXISTS trg_driver_documents_updated_at ON driver_documents;
CREATE TRIGGER trg_driver_documents_updated_at
BEFORE UPDATE ON driver_documents
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 5.2 Vehicle Compliance Documents
CREATE TABLE IF NOT EXISTS vehicle_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN (
        'REGISTRATION_CERTIFICATE',
        'COMMERCIAL_INSURANCE',
        'PUC',
        'FITNESS_CERTIFICATE',
        'COMMERCIAL_PERMIT',
        'VEHICLE_TAX'
    )),
    document_number VARCHAR(100),
    storage_path TEXT NOT NULL,
    mime_type VARCHAR(50) NOT NULL,
    issued_date DATE,
    expiry_date DATE,
    verification_status VARCHAR(30) DEFAULT 'PENDING_REVIEW' CHECK (verification_status IN (
        'PENDING_REVIEW', 'VERIFIED', 'REJECTED', 'ACTION_REQUIRED', 'EXPIRED'
    )),
    rejection_reason TEXT,
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_vehicle_doc UNIQUE(vehicle_id, document_type)
);
CREATE INDEX IF NOT EXISTS idx_vehicle_docs_expiry ON vehicle_documents(expiry_date);
CREATE INDEX IF NOT EXISTS idx_vehicle_docs_status ON vehicle_documents(verification_status);

DROP TRIGGER IF EXISTS trg_vehicle_documents_updated_at ON vehicle_documents;
CREATE TRIGGER trg_vehicle_documents_updated_at
BEFORE UPDATE ON vehicle_documents
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 5.3 Verification Records (Immutable Administrative Audit Trail)
CREATE TABLE IF NOT EXISTS verification_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES users(id),
    target_type VARCHAR(20) NOT NULL CHECK (target_type IN ('DRIVER', 'VEHICLE', 'DOCUMENT')),
    target_id UUID NOT NULL,
    previous_status VARCHAR(30) NOT NULL,
    new_status VARCHAR(30) NOT NULL,
    decision_reason TEXT,
    verification_metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_verif_records_target ON verification_records(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_verif_records_admin ON verification_records(admin_id);

-- -----------------------------------------------------------------------------
-- 6. Catalog, Pricing Rules & Booking Policies
-- -----------------------------------------------------------------------------

-- 6.1 Service Categories
CREATE TABLE IF NOT EXISTS service_categories (
    id VARCHAR(50) PRIMARY KEY, -- SVC_BARAAT, SVC_VIDAI, SVC_MULTIDAY, SVC_RECEPTION
    title VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 6.2 Service Addons
CREATE TABLE IF NOT EXISTS service_addons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_category_id VARCHAR(50) REFERENCES service_categories(id),
    name VARCHAR(150) NOT NULL,
    description TEXT,
    price_paise BIGINT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 6.3 Config-Driven Pricing Rules
CREATE TABLE IF NOT EXISTS pricing_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_category_id VARCHAR(50) REFERENCES service_categories(id),
    vehicle_class VARCHAR(40) NOT NULL,
    city_code VARCHAR(10) NOT NULL, -- DEL, JAI, UDR, MUM, BLR
    base_hours INT NOT NULL,
    base_km INT NOT NULL,
    base_rate_paise BIGINT NOT NULL,
    extra_hour_rate_paise BIGINT NOT NULL,
    extra_km_rate_paise BIGINT NOT NULL,
    night_allowance_paise BIGINT DEFAULT 0,
    muhurat_multiplier NUMERIC(3,2) DEFAULT 1.00,
    effective_from TIMESTAMPTZ NOT NULL,
    effective_to TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_pricing_rules_lookup ON pricing_rules(service_category_id, vehicle_class, city_code);

-- 6.4 Booking Policies
CREATE TABLE IF NOT EXISTS booking_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_name VARCHAR(100) NOT NULL,
    advance_token_percentage NUMERIC(5,2) NOT NULL DEFAULT 25.00,
    cancellation_tiers JSONB NOT NULL, -- e.g. [{"hours_before": 48, "refund_percent": 100}, {"hours_before": 24, "refund_percent": 50}]
    grace_period_minutes INT DEFAULT 30,
    overtime_increment_minutes INT DEFAULT 30,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 7. Ceremonial Bookings & State Machine
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_code VARCHAR(30) UNIQUE NOT NULL, -- e.g. SD-2026-0100
    customer_id UUID NOT NULL REFERENCES users(id),
    driver_id UUID REFERENCES drivers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    service_category_id VARCHAR(50) REFERENCES service_categories(id),
    pricing_rule_id UUID REFERENCES pricing_rules(id),
    booking_policy_id UUID REFERENCES booking_policies(id),
    
    ceremony_type VARCHAR(50) NOT NULL, -- Baraat, Vidai, Reception, Sangeet, Mehendi
    ceremonial_attire VARCHAR(100) NOT NULL,
    special_instructions TEXT,
    
    -- Explicit Service Timing
    service_start_time TIMESTAMPTZ NOT NULL,
    service_end_time TIMESTAMPTZ NOT NULL,
    is_overnight BOOLEAN GENERATED ALWAYS AS (service_end_time::date > service_start_time::date) STORED,
    
    -- Route & Itinerary
    city VARCHAR(50) NOT NULL,
    pickup_address TEXT NOT NULL,
    pickup_location GEOGRAPHY(POINT, 4326),
    destination_address TEXT NOT NULL,
    destination_location GEOGRAPHY(POINT, 4326),
    venue_name VARCHAR(150),
    landmark_instructions TEXT,
    route_distance_km NUMERIC(6, 2),
    
    -- Host Primary Contact
    primary_contact_name VARCHAR(120) NOT NULL,
    primary_contact_phone VARCHAR(20) NOT NULL,
    passenger_count INT DEFAULT 2,
    
    -- Pricing Breakdown (in Paise)
    estimated_total_paise BIGINT NOT NULL,
    advance_token_paise BIGINT NOT NULL,
    advance_token_label VARCHAR(60),
    is_advance_paid BOOLEAN DEFAULT FALSE,
    final_settled_paise BIGINT,
    
    -- State Machine & Security
    status VARCHAR(40) NOT NULL DEFAULT 'REQUESTED' CHECK (status IN (
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
    )),
    start_otp VARCHAR(6) DEFAULT '1234',
    version INT NOT NULL DEFAULT 1, -- Optimistic concurrency locking
    idempotency_key VARCHAR(100) UNIQUE NOT NULL,
    
    submitted_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_bookings_customer ON bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_driver ON bookings(driver_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_timing ON bookings(service_start_time, service_end_time);

DROP TRIGGER IF EXISTS trg_bookings_updated_at ON bookings;
CREATE TRIGGER trg_bookings_updated_at
BEFORE UPDATE ON bookings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Booking Addons Junction
CREATE TABLE IF NOT EXISTS booking_addons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    addon_id UUID NOT NULL REFERENCES service_addons(id),
    quantity INT DEFAULT 1,
    unit_price_paise BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_booking_addons_booking ON booking_addons(booking_id);

-- Double-booking prevention time-slot lock
CREATE TABLE IF NOT EXISTS availabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(30) DEFAULT 'BOOKED' CHECK (status IN (
        'AVAILABLE', 'BLOCKED', 'BOOKED', 'MAINTENANCE'
    )),
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_avail_range CHECK (end_time > start_time)
);
CREATE INDEX IF NOT EXISTS idx_avail_driver_time ON availabilities(driver_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_avail_vehicle_time ON availabilities(vehicle_id, start_time, end_time);

-- Standby Reserve Pool for Emergency Replacement
CREATE TABLE IF NOT EXISTS standby_pool (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    city VARCHAR(50) NOT NULL,
    driver_id UUID NOT NULL REFERENCES drivers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    standby_date DATE NOT NULL,
    shift_start TIMESTAMPTZ NOT NULL,
    shift_end TIMESTAMPTZ NOT NULL,
    status VARCHAR(30) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'DISPATCHED', 'RELEASED')),
    dispatched_booking_id UUID REFERENCES bookings(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_standby_city_date ON standby_pool(city, standby_date, status);

-- Immutable Append-Only Transition Event Log
CREATE TABLE IF NOT EXISTS booking_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    from_status VARCHAR(40) NOT NULL,
    to_status VARCHAR(40) NOT NULL,
    triggered_by_user_id UUID NOT NULL REFERENCES users(id),
    trigger_role VARCHAR(30) NOT NULL,
    event_reason TEXT,
    event_metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_booking_events_booking ON booking_events(booking_id, created_at);

-- -----------------------------------------------------------------------------
-- 8. Payments, Payouts & Settlement Ledger
-- -----------------------------------------------------------------------------

-- 8.1 Customer Payments (Razorpay / Cashfree)
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id),
    customer_id UUID NOT NULL REFERENCES users(id),
    payment_type VARCHAR(30) NOT NULL CHECK (payment_type IN (
        'ADVANCE_TOKEN', 'BALANCE_SETTLEMENT', 'OVERTIME_CHARGE', 'TIP', 'REFUND'
    )),
    amount_paise BIGINT NOT NULL,
    currency VARCHAR(5) DEFAULT 'INR',
    gateway VARCHAR(30) NOT NULL DEFAULT 'RAZORPAY',
    gateway_order_id VARCHAR(100),
    gateway_payment_id VARCHAR(100),
    gateway_signature VARCHAR(255),
    status VARCHAR(30) DEFAULT 'INITIATED' CHECK (status IN (
        'INITIATED', 'SUCCESS', 'FAILED', 'REFUNDED'
    )),
    failure_code VARCHAR(50),
    failure_message TEXT,
    idempotency_key VARCHAR(100) UNIQUE,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_payments_gateway_order ON payments(gateway_order_id);

-- 8.2 Driver & Fleet Payouts
CREATE TABLE IF NOT EXISTS payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id),
    beneficiary_user_id UUID NOT NULL REFERENCES users(id),
    beneficiary_role VARCHAR(30) NOT NULL,
    gross_amount_paise BIGINT NOT NULL,
    platform_commission_paise BIGINT NOT NULL,
    tds_deduction_paise BIGINT NOT NULL DEFAULT 0,
    net_payout_paise BIGINT NOT NULL,
    status VARCHAR(30) DEFAULT 'PENDING' CHECK (status IN (
        'PENDING', 'PROCESSING', 'SETTLED', 'FAILED'
    )),
    transfer_reference VARCHAR(100),
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_payouts_beneficiary ON payouts(beneficiary_user_id);

-- 8.3 Detailed Ledger Entries (Double-Entry Ready)
CREATE TABLE IF NOT EXISTS payout_ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payout_id UUID REFERENCES payouts(id) ON DELETE CASCADE,
    account_type VARCHAR(40) NOT NULL, -- DRIVER_PAYABLE, PLATFORM_REVENUE, TDS_LIABILITY, ESCROW_HOLD
    entry_type VARCHAR(10) NOT NULL CHECK (entry_type IN ('CREDIT', 'DEBIT')),
    amount_paise BIGINT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_ledger_payout ON payout_ledger_entries(payout_id);

-- -----------------------------------------------------------------------------
-- 9. Customer Addresses, Notifications, Reviews & Messages
-- -----------------------------------------------------------------------------

-- 9.1 Saved Addresses
CREATE TABLE IF NOT EXISTS saved_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(50) NOT NULL, -- Home, Ceremony Venue, Hotel
    address_line TEXT NOT NULL,
    city VARCHAR(50) NOT NULL,
    landmark VARCHAR(120),
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_saved_addr_user ON saved_addresses(user_id);

-- 9.2 In-App Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    body TEXT NOT NULL,
    data_payload JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);

-- 9.3 Customer Reviews
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID UNIQUE NOT NULL REFERENCES bookings(id),
    customer_id UUID NOT NULL REFERENCES users(id),
    driver_id UUID NOT NULL REFERENCES drivers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    overall_rating INT NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
    punctuality_rating INT CHECK (punctuality_rating BETWEEN 1 AND 5),
    grooming_rating INT CHECK (grooming_rating BETWEEN 1 AND 5),
    cleanliness_rating INT CHECK (cleanliness_rating BETWEEN 1 AND 5),
    driving_rating INT CHECK (driving_rating BETWEEN 1 AND 5),
    feedback_text TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_reviews_driver ON reviews(driver_id);

-- 9.4 In-App Messages
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id),
    recipient_id UUID NOT NULL REFERENCES users(id),
    message_type VARCHAR(20) DEFAULT 'TEXT',
    body TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_messages_booking ON messages(booking_id, created_at);

-- -----------------------------------------------------------------------------
-- 10. Administrative Audit Logs
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES users(id),
    actor_role VARCHAR(30),
    action VARCHAR(100) NOT NULL,
    target_entity VARCHAR(50),
    target_id UUID,
    ip_address INET,
    user_agent TEXT,
    changes JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);

-- -----------------------------------------------------------------------------
-- 11. Row-Level Security (RLS) Policies
-- -----------------------------------------------------------------------------

-- Enable RLS across sensitive tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- 11.1 Users RLS
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'users_self_read') THEN
        CREATE POLICY users_self_read ON users FOR SELECT USING (auth.uid() = id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'users_self_update') THEN
        CREATE POLICY users_self_update ON users FOR UPDATE USING (auth.uid() = id);
    END IF;
END $$;

-- 11.2 Bookings RLS
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'bookings_customer_read') THEN
        CREATE POLICY bookings_customer_read ON bookings FOR SELECT USING (auth.uid() = customer_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'bookings_driver_read') THEN
        CREATE POLICY bookings_driver_read ON bookings FOR SELECT USING (auth.uid() = driver_id);
    END IF;
END $$;

-- 11.3 Notifications RLS
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'notifications_owner_all') THEN
        CREATE POLICY notifications_owner_all ON notifications FOR ALL USING (auth.uid() = user_id);
    END IF;
END $$;

-- 11.4 Saved Addresses RLS
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'saved_addresses_owner_all') THEN
        CREATE POLICY saved_addresses_owner_all ON saved_addresses FOR ALL USING (auth.uid() = user_id);
    END IF;
END $$;

-- 11.5 Driver Documents RLS
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'driver_documents_owner_read') THEN
        CREATE POLICY driver_documents_owner_read ON driver_documents FOR SELECT USING (auth.uid() = driver_id);
    END IF;
END $$;

-- 11.6 Admin Full Access Bypass
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'admin_users_all') THEN
        CREATE POLICY admin_users_all ON users FOR ALL USING ((auth.jwt() ->> 'role') IN ('operationsAdmin', 'verificationAdmin', 'superAdmin'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'admin_bookings_all') THEN
        CREATE POLICY admin_bookings_all ON bookings FOR ALL USING ((auth.jwt() ->> 'role') IN ('operationsAdmin', 'verificationAdmin', 'superAdmin'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'admin_driver_docs_all') THEN
        CREATE POLICY admin_driver_docs_all ON driver_documents FOR ALL USING ((auth.jwt() ->> 'role') IN ('operationsAdmin', 'verificationAdmin', 'superAdmin'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'admin_audit_logs_all') THEN
        CREATE POLICY admin_audit_logs_all ON audit_logs FOR ALL USING ((auth.jwt() ->> 'role') IN ('operationsAdmin', 'verificationAdmin', 'superAdmin'));
    END IF;
END $$;

-- End of Migration 0001_init.sql
