-- =============================================================================
-- ShadiDriver seed data for local / pilot development
-- Demo phones match the Flutter mock accounts.
-- OTP in development: 000000 (universal) plus role codes (111111 customer, etc.)
-- =============================================================================

INSERT INTO platform_settings (key, value, description) VALUES
    ('gst_rate', '0.05', 'GST applied on ceremony transport subtotal'),
    ('platform_commission_rate', '0.20', 'Platform take-rate on gross booking amount'),
    ('tds_rate', '0.01', 'TDS withheld on chauffeur payouts'),
    ('acceptance_timeout_minutes', '30', 'REQUESTED -> EXPIRED if no chauffeur accepts'),
    ('payment_window_minutes', '15', 'PAYMENT_PENDING -> EXPIRED if token not captured'),
    ('payment_retry_window_minutes', '60', 'PAYMENT_FAILED retry grace window'),
    ('geofence_radius_meters', '200', 'Venue arrival geofence'),
    ('otp_ttl_seconds', '120', 'Phone OTP validity'),
    ('otp_resend_seconds', '30', 'Minimum gap between OTP sends'),
    ('otp_max_per_window', '3', 'Max OTP requests per phone per 5 minutes'),
    ('access_token_ttl_seconds', '900', 'JWT access token TTL (15 min)'),
    ('refresh_token_ttl_days', '30', 'Refresh token lifetime'),
    ('timestamp_drift_seconds', '300', 'Reject telemetry older/newer than 5 minutes')
ON CONFLICT (key) DO NOTHING;

INSERT INTO service_categories (id, title, description, display_order, is_active, asset_path) VALUES
    ('SVC_BARAAT', 'Baraat Procession', 'Groom procession with luxury chauffeur, safa coordination, and slow ceremonial pace.', 1, TRUE, 'assets/categories/baraat.png'),
    ('SVC_VIDAI', 'Vidai', 'Emotional farewell transfer for the bride with discreet, experienced chauffeur.', 2, TRUE, 'assets/categories/vidai.png'),
    ('SVC_ENTRY', 'Bride & Groom Entry', 'Grand venue arrival for pheras, reception, or sangeet entry.', 3, TRUE, 'assets/categories/entry.png'),
    ('SVC_RECEPTION', 'Reception VIP', 'Guest and VIP shuttle for reception hospitality.', 4, TRUE, 'assets/categories/reception.png'),
    ('SVC_MULTIDAY', 'Multi-Day Wedding', '2–5 day wedding coverage split into chauffeur shift segments.', 5, TRUE, 'assets/categories/multiday.png')
ON CONFLICT (id) DO NOTHING;

INSERT INTO booking_policies (id, policy_name, advance_token_percentage, cancellation_tiers, grace_period_minutes, overtime_increment_minutes, is_default)
VALUES (
    'b0000000-0000-4000-8000-000000000001',
    'Default Ceremonial Policy',
    25.00,
    '[
        {"hours_before": 168, "refund_percent": 100},
        {"hours_before": 72, "refund_percent": 75},
        {"hours_before": 24, "refund_percent": 50},
        {"hours_before": 0, "refund_percent": 0}
    ]'::jsonb,
    30,
    30,
    TRUE
) ON CONFLICT DO NOTHING;

-- Pricing rules: Delhi & Jaipur, four vehicle classes
INSERT INTO pricing_rules (
    id, service_category_id, vehicle_class, city_code,
    base_hours, base_km, base_rate_paise, extra_hour_rate_paise, extra_km_rate_paise,
    night_allowance_paise, muhurat_multiplier, effective_from, is_active
) VALUES
    ('c0000000-0000-4000-8000-000000000001', 'SVC_BARAAT', 'LUXURY_SEDAN', 'DEL', 5, 50, 1200000, 250000, 4000, 150000, 1.15, NOW() - INTERVAL '1 day', TRUE),
    ('c0000000-0000-4000-8000-000000000002', 'SVC_BARAAT', 'ULTRA_LUXURY', 'DEL', 5, 50, 2200000, 400000, 6000, 250000, 1.15, NOW() - INTERVAL '1 day', TRUE),
    ('c0000000-0000-4000-8000-000000000003', 'SVC_BARAAT', 'VINTAGE', 'DEL', 5, 40, 1800000, 350000, 5000, 200000, 1.20, NOW() - INTERVAL '1 day', TRUE),
    ('c0000000-0000-4000-8000-000000000004', 'SVC_BARAAT', 'EXECUTIVE_MPV', 'DEL', 5, 60, 900000, 180000, 3000, 100000, 1.10, NOW() - INTERVAL '1 day', TRUE),
    ('c0000000-0000-4000-8000-000000000005', 'SVC_VIDAI', 'LUXURY_SEDAN', 'DEL', 4, 40, 1000000, 220000, 4000, 150000, 1.10, NOW() - INTERVAL '1 day', TRUE),
    ('c0000000-0000-4000-8000-000000000006', 'SVC_ENTRY', 'LUXURY_SEDAN', 'DEL', 3, 30, 800000, 220000, 4000, 100000, 1.10, NOW() - INTERVAL '1 day', TRUE),
    ('c0000000-0000-4000-8000-000000000007', 'SVC_RECEPTION', 'EXECUTIVE_MPV', 'DEL', 6, 80, 1100000, 160000, 2500, 120000, 1.05, NOW() - INTERVAL '1 day', TRUE),
    ('c0000000-0000-4000-8000-000000000008', 'SVC_MULTIDAY', 'LUXURY_SEDAN', 'DEL', 8, 100, 2800000, 250000, 4000, 200000, 1.00, NOW() - INTERVAL '1 day', TRUE),
    ('c0000000-0000-4000-8000-000000000011', 'SVC_BARAAT', 'LUXURY_SEDAN', 'JAI', 5, 50, 1100000, 230000, 3800, 140000, 1.15, NOW() - INTERVAL '1 day', TRUE),
    ('c0000000-0000-4000-8000-000000000012', 'SVC_BARAAT', 'ULTRA_LUXURY', 'JAI', 5, 50, 2000000, 380000, 5500, 230000, 1.15, NOW() - INTERVAL '1 day', TRUE)
ON CONFLICT DO NOTHING;

INSERT INTO service_addons (id, service_category_id, name, description, price_paise, is_active, features) VALUES
    ('d0000000-0000-4000-8000-000000000001', 'SVC_BARAAT', 'Royal Bandhgala + Safa', 'Chauffeur ceremonial bandhgala with coordinated safa.', 150000, TRUE, '["Bandhgala","Safa","Brooch"]'),
    ('d0000000-0000-4000-8000-000000000002', 'SVC_BARAAT', 'Floral Car Coordination', 'Fresh marigold and rose garland setup on bonnet and roof rails.', 250000, TRUE, '["Garlands","Bonnet decor"]'),
    ('d0000000-0000-4000-8000-000000000003', 'SVC_VIDAI', 'Privacy Partition & Soft Lighting', 'Discreet cabin lighting and privacy for vidai transfer.', 120000, TRUE, '["Cabin lighting","Privacy"]'),
    ('d0000000-0000-4000-8000-000000000004', 'SVC_RECEPTION', 'VIP Water & Amenities Tray', 'Bottled water, mints, and welcome towels for guests.', 80000, TRUE, '["Water","Towels"]')
ON CONFLICT DO NOTHING;

-- Demo users (phones match Flutter MockAuthRepository)
INSERT INTO users (id, phone_number, country_code, email, full_name, primary_role, account_status, is_active, is_phone_verified)
VALUES
    ('a1111111-1111-4111-8111-111111111111', '+919810000001', '+91', 'kabir.sharma@example.com', 'Kabir Sharma', 'customer', 'ACTIVE', TRUE, TRUE),
    ('a2222222-2222-4222-8222-222222222222', '+919810000002', '+91', 'rajesh.singh@example.com', 'Rajesh Singh', 'driver', 'ACTIVE', TRUE, TRUE),
    ('a3333333-3333-4333-8333-333333333333', '+919810000003', '+91', 'vikram.malhotra@shadidriver.com', 'Vikram Malhotra', 'operationsAdmin', 'ACTIVE', TRUE, TRUE),
    ('a4444444-4444-4444-8444-444444444444', '+919810000004', '+91', 'new.customer@example.com', 'New Customer', 'customer', 'PROFILE_INCOMPLETE', TRUE, TRUE),
    ('a5555555-5555-4555-8555-555555555555', '+919810000005', '+91', 'new.driver@example.com', 'New Driver', 'driver', 'PROFILE_INCOMPLETE', TRUE, TRUE),
    ('a6666666-6666-4666-8666-666666666666', '+919876543210', '+91', 'host@example.com', 'Kabir Sharma', 'customer', 'ACTIVE', TRUE, TRUE),
    ('a7777777-7777-4777-8777-777777777777', '+919876500002', '+91', 'rajesh.alt@example.com', 'Rajesh Singh', 'driver', 'ACTIVE', TRUE, TRUE),
    ('a8888888-8888-4888-8888-888888888888', '+919876500003', '+91', 'ops.alt@shadidriver.com', 'Vikram Malhotra', 'operationsAdmin', 'ACTIVE', TRUE, TRUE),
    ('a9999999-9999-4999-8999-999999999999', '+919810000009', '+91', 'verify.admin@shadidriver.com', 'Meera Kapoor', 'verificationAdmin', 'ACTIVE', TRUE, TRUE),
    ('aa101010-1010-4101-8101-101010101010', '+919810000006', '+91', 'finance.admin@shadidriver.com', 'Arjun Mehta', 'financeAdmin', 'ACTIVE', TRUE, TRUE),
    ('aa121212-1212-4121-8121-121212121212', '+919810000099', '+91', 'super.admin@shadidriver.com', 'ShadiDriver HQ', 'superAdmin', 'ACTIVE', TRUE, TRUE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO customers (id, emergency_contact_name, emergency_contact_phone, preferred_language, city)
VALUES
    ('a1111111-1111-4111-8111-111111111111', 'Ananya Sharma', '+919810009001', 'en', 'Delhi'),
    ('a4444444-4444-4444-8444-444444444444', NULL, NULL, 'en', ''),
    ('a6666666-6666-4666-8666-666666666666', 'Ananya Sharma', '+919810009001', 'en', 'Delhi')
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (
    id, date_of_birth, experience_years, license_number, languages_spoken,
    ceremonial_attire_sizes, duty_status, verification_status, is_online,
    average_rating, total_trips_completed, bio, operating_area, wedding_experience_years,
    document_status, vehicle_status, police_clearance_status, ceremonial_attire_status
) VALUES
    (
        'a2222222-2222-4222-8222-222222222222',
        '1988-03-12', 12, 'DL-07-20140012345', ARRAY['Hindi','English','Punjabi'],
        '{"suit":"42R","safa":"L","height_cm":180}'::jsonb,
        'AVAILABLE', 'APPROVED', TRUE, 4.90, 186,
        'Wedding specialist chauffeur with 12 years of baraat and vidai experience across Delhi NCR.',
        'Delhi NCR', 8, 'VERIFIED', 'ASSIGNED_MERCEDES_ECLASS', 'CLEARED', 'READY'
    ),
    (
        'a7777777-7777-4777-8777-777777777777',
        '1988-03-12', 12, 'DL-07-20140019999', ARRAY['Hindi','English'],
        '{"suit":"42R","safa":"L","height_cm":180}'::jsonb,
        'AVAILABLE', 'APPROVED', TRUE, 4.90, 186,
        'Wedding specialist chauffeur.', 'Delhi NCR', 8, 'VERIFIED', 'ASSIGNED_MERCEDES_ECLASS', 'CLEARED', 'READY'
    ),
    (
        'a5555555-5555-4555-8555-555555555555',
        '1995-01-01', 3, 'DL-07-PENDING0001', ARRAY['Hindi'],
        '{}'::jsonb, 'OFFLINE', 'PENDING_SUBMISSION', FALSE, 5.00, 0,
        '', '', 0, 'PENDING_SUBMISSION', '', 'PENDING', 'PENDING'
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO vehicles (
    id, fleet_code, independent_driver_id, make, model, year_of_manufacture, color,
    registration_number, seating_capacity, fuel_type, vehicle_class, is_vintage,
    base_price_paise, city, image_url, verification_status, is_available, is_active,
    amenities, gallery_urls, transmission, suitability_info, suitable_ceremonies
) VALUES
    (
        'e0000000-0000-4000-8000-000000000001', 'SD-DEL-001',
        'a2222222-2222-4222-8222-222222222222',
        'Mercedes-Benz', 'E-Class', 2023, 'Obsidian Black',
        'DL1CA1234', 4, 'PETROL', 'LUXURY_SEDAN', FALSE,
        1200000, 'Delhi',
        'https://cdn.shadidriver.local/vehicles/eclass.jpg',
        'APPROVED', TRUE, TRUE,
        '["Dual climate","Ambient lighting","Champagne cooler"]'::jsonb,
        '["https://cdn.shadidriver.local/vehicles/eclass.jpg"]'::jsonb,
        'AUTOMATIC', 'Ideal for baraat lead car and vidai.',
        '["SVC_BARAAT","SVC_VIDAI","SVC_ENTRY"]'::jsonb
    ),
    (
        'e0000000-0000-4000-8000-000000000002', 'SD-DEL-002',
        'a2222222-2222-4222-8222-222222222222',
        'BMW', '5 Series', 2022, 'Mineral White',
        'DL1CA5678', 4, 'PETROL', 'ULTRA_LUXURY', FALSE,
        2200000, 'Delhi',
        'https://cdn.shadidriver.local/vehicles/5series.jpg',
        'APPROVED', TRUE, TRUE,
        '["Massage seats","Panoramic roof"]'::jsonb,
        '["https://cdn.shadidriver.local/vehicles/5series.jpg"]'::jsonb,
        'AUTOMATIC', 'Ultra luxury entry and VIP reception.',
        '["SVC_ENTRY","SVC_RECEPTION","SVC_BARAAT"]'::jsonb
    ),
    (
        'e0000000-0000-4000-8000-000000000003', 'SD-DEL-003',
        NULL,
        'Toyota', 'Innova Hycross', 2024, 'Pearl White',
        'DL1CA9012', 7, 'HYBRID', 'EXECUTIVE_MPV', FALSE,
        900000, 'Delhi',
        'https://cdn.shadidriver.local/vehicles/hycross.jpg',
        'APPROVED', TRUE, TRUE,
        '["Captain seats","Dual AC"]'::jsonb,
        '["https://cdn.shadidriver.local/vehicles/hycross.jpg"]'::jsonb,
        'AUTOMATIC', 'Family and guest shuttle for reception and multi-day.',
        '["SVC_RECEPTION","SVC_MULTIDAY"]'::jsonb
    )
ON CONFLICT (id) DO NOTHING;
