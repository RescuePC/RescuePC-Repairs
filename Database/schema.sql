-- RescuePC Licensing Database Schema
-- Run this in your PostgreSQL database console (Neon, Railway, or Supabase)

-- Customers table
CREATE TABLE customers (
    id          SERIAL PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Packages table
CREATE TABLE packages (
    id            SERIAL PRIMARY KEY,
    code          TEXT NOT NULL UNIQUE,    -- 'BASIC', 'PRO', etc.
    name          TEXT NOT NULL,
    duration_days INTEGER NOT NULL
);

-- Licenses table
CREATE TABLE licenses (
    id           SERIAL PRIMARY KEY,
    customer_id  INTEGER NOT NULL REFERENCES customers(id),
    package_id   INTEGER NOT NULL REFERENCES packages(id),
    license_key  TEXT NOT NULL UNIQUE,
    purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at   TIMESTAMPTZ NOT NULL,
    status       TEXT NOT NULL CHECK (status IN ('active', 'expired', 'revoked'))
);

-- Example seed data (optional, for testing)
-- Insert a test package
INSERT INTO packages (code, name, duration_days) VALUES
    ('BASIC', 'Basic Package', 30),
    ('PRO', 'Professional Package', 365);

-- Example: Insert a test customer and license (adjust dates as needed)
-- INSERT INTO customers (email) VALUES ('test@example.com');
-- INSERT INTO licenses (customer_id, package_id, license_key, expires_at, status)
-- VALUES (
--     (SELECT id FROM customers WHERE email = 'test@example.com'),
--     (SELECT id FROM packages WHERE code = 'BASIC'),
--     'TEST-KEY-123',
--     NOW() + INTERVAL '30 days',
--     'active'
-- );

