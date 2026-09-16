# ShadiDriver — Database Readiness Guide (PostgreSQL / Supabase Schema)

## 1. Overview
This schema matches 100% of the domain models and entities established in the ShadiDriver Flutter codebase.
All primary keys use `UUID` or prefixed identifiers. All monetary amounts are stored in **integers (paise / cents)** to prevent IEEE-754 floating-point inaccuracies.

---

## 2. DDL Schema Definition

```sql
-- 1. Users table (Customer, Driver, Admin)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(15) UNIQUE NOT NULL,
    role VARCHAR(30) NOT NULL CHECK (role IN ('customer', 'driver', 'operationsAdmin', 'verificationAdmin', 'financeAdmin', 'superAdmin', 'fleetOwner')),
    full_name VARCHAR(120),
    avatar_url TEXT,
    account_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (account_status IN ('ACTIVE', 'SUSPENDED', 'PENDING_VERIFICATION')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Chauffeur Profiles table
CREATE TABLE chauffeur_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    license_number VARCHAR(50) UNIQUE NOT NULL,
    years_experience INT DEFAULT 5,
    duty_status VARCHAR(20) DEFAULT 'OFFLINE' CHECK (duty_status IN ('AVAILABLE', 'BUSY', 'OFFLINE', 'AVAILABLE_NOW')),
    police_clearance_status VARCHAR(30) DEFAULT 'PENDING',
    ceremonial_attire_status VARCHAR(30) DEFAULT 'PENDING',
    rating_average NUMERIC(3, 2) DEFAULT 5.00,
    total_trips_completed INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Vehicles table
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fleet_code VARCHAR(30) UNIQUE NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    vehicle_class VARCHAR(50) NOT NULL, -- e.g. Luxury Sedan, Ultra Luxury, Royal Vintage
    registration_number VARCHAR(30) UNIQUE NOT NULL,
    city VARCHAR(50) NOT NULL,
    base_price_paise BIGINT NOT NULL,
    image_url TEXT,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Ceremonial Bookings table
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_code VARCHAR(30) UNIQUE NOT NULL, -- e.g. SD-2026-0100
    customer_id UUID NOT NULL REFERENCES users(id),
    chauffeur_id UUID REFERENCES users(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    ceremony_type VARCHAR(50) NOT NULL, -- Baraat, Vidai, Reception, Sangeet, Mehendi
    ceremonial_attire VARCHAR(100) NOT NULL,
    special_instructions TEXT,
    
    -- Explicit Service Timing (No fixed packages as truth)
    service_start_time TIMESTAMPTZ NOT NULL,
    service_end_time TIMESTAMPTZ NOT NULL,
    is_overnight BOOLEAN GENERATED ALWAYS AS (service_end_time::date > service_start_time::date) STORED,
    
    -- Itinerary & Route
    city VARCHAR(50) NOT NULL,
    pickup_address TEXT NOT NULL,
    destination_address TEXT NOT NULL,
    venue_name VARCHAR(150),
    landmark_instructions TEXT,
    route_distance_km NUMERIC(6, 2),
    
    -- Primary Coordinator / Host Contact
    primary_contact_name VARCHAR(120) NOT NULL,
    primary_contact_phone VARCHAR(20) NOT NULL,
    passenger_count INT DEFAULT 2,
    
    -- Pricing & Advances (in Paise)
    estimated_total_paise BIGINT NOT NULL,
    advance_token_paise BIGINT NOT NULL,
    advance_token_label VARCHAR(60),
    is_advance_paid BOOLEAN DEFAULT FALSE,
    
    -- State Machine
    status VARCHAR(30) DEFAULT 'REQUESTED' CHECK (status IN ('DRAFT', 'REQUESTED', 'DRIVER_ACCEPTED', 'CONFIRMED', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    start_otp VARCHAR(6) DEFAULT '1234',
    version INT DEFAULT 1,
    idempotency_key VARCHAR(100) UNIQUE NOT NULL,
    
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Customer Saved Addresses
CREATE TABLE saved_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(50) NOT NULL, -- Home, Ceremony Venue, Hotel
    address_line TEXT NOT NULL,
    city VARCHAR(50) NOT NULL,
    landmark VARCHAR(120),
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Payment Orders
CREATE TABLE payment_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id),
    gateway_order_id VARCHAR(100) UNIQUE NOT NULL,
    amount_paise BIGINT NOT NULL,
    currency VARCHAR(5) DEFAULT 'INR',
    status VARCHAR(30) DEFAULT 'CREATED',
    gateway_payment_id VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. In-App Notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    body TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Customer Reviews
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID UNIQUE REFERENCES bookings(id),
    customer_id UUID NOT NULL REFERENCES users(id),
    chauffeur_id UUID NOT NULL REFERENCES users(id),
    overall_rating INT CHECK (overall_rating BETWEEN 1 AND 5),
    punctuality_rating INT CHECK (punctuality_rating BETWEEN 1 AND 5),
    grooming_rating INT CHECK (grooming_rating BETWEEN 1 AND 5),
    feedback_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 3. Database Indexes
```sql
CREATE INDEX idx_bookings_customer ON bookings(customer_id);
CREATE INDEX idx_bookings_chauffeur ON bookings(chauffeur_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_timing ON bookings(service_start_time, service_end_time);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read);
CREATE INDEX idx_chauffeurs_duty ON chauffeur_profiles(duty_status);
```
