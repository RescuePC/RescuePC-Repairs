-- RescuePC Licensing Database Setup
-- PostgreSQL Schema - Production Ready

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-------------------------
-- 1. Core customer data
-------------------------
CREATE TABLE IF NOT EXISTS customers (
    customer_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT NOT NULL UNIQUE,
    full_name     TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS plans (
    plan_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_code        TEXT NOT NULL UNIQUE,
    name             TEXT NOT NULL,
    description      TEXT,
    price_cents      INTEGER NOT NULL,
    billing_interval TEXT NOT NULL CHECK (
        billing_interval IN ('month', 'year', 'lifetime')
    ),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS licenses (
    license_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_key       TEXT NOT NULL UNIQUE,
    customer_id       UUID NOT NULL REFERENCES customers(customer_id),
    plan_id           UUID NOT NULL REFERENCES plans(plan_id),
    status            TEXT NOT NULL CHECK (
        status IN ('active', 'expired', 'revoked', 'trial')
    ),
    max_devices       INTEGER NOT NULL DEFAULT 1,
    issued_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at        TIMESTAMPTZ,
    last_validated_at TIMESTAMPTZ
);

-------------------------
-- 2. Device tracking
-------------------------
CREATE TABLE IF NOT EXISTS machines (
    machine_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_id          UUID NOT NULL REFERENCES licenses(license_id) ON DELETE CASCADE,
    machine_fingerprint TEXT NOT NULL,
    first_seen_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (license_id, machine_fingerprint)
);

CREATE TABLE IF NOT EXISTS repair_sessions (
    session_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_id   UUID NOT NULL REFERENCES licenses(license_id) ON DELETE CASCADE,
    machine_id   UUID NOT NULL REFERENCES machines(machine_id) ON DELETE CASCADE,
    started_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at     TIMESTAMPTZ,
    os_type      TEXT,
    tool_version TEXT,
    status       TEXT CHECK (
        status IN ('running', 'completed', 'failed', 'cancelled')
    ),
    error_code   TEXT,
    log_url      TEXT
);

-------------------------
-- 3. Indexes for performance
-------------------------
CREATE INDEX IF NOT EXISTS idx_licenses_key ON licenses(license_key);
CREATE INDEX IF NOT EXISTS idx_licenses_customer ON licenses(customer_id);
CREATE INDEX IF NOT EXISTS idx_licenses_status ON licenses(status);
CREATE INDEX IF NOT EXISTS idx_licenses_expires ON licenses(expires_at);
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);
CREATE INDEX IF NOT EXISTS idx_machines_license ON machines(license_id);
CREATE INDEX IF NOT EXISTS idx_repair_sessions_license ON repair_sessions(license_id);

-------------------------
-- 4. Seed data (safe to re-run)
-------------------------
INSERT INTO plans (plan_code, name, description, price_cents, billing_interval)
VALUES
  ('BASIC_MONTHLY', 'Basic Monthly', 'Entry tier for home users', 1999, 'month')
ON CONFLICT (plan_code) DO NOTHING;

INSERT INTO customers (email, full_name)
VALUES
  ('test@example.com', 'Test User')
ON CONFLICT (email) DO NOTHING;

INSERT INTO licenses (
    license_key,
    customer_id,
    plan_id,
    status,
    max_devices,
    issued_at,
    expires_at
)
VALUES (
    'TEST-KEY',
    (SELECT customer_id FROM customers WHERE email = 'test@example.com'),
    (SELECT plan_id FROM plans WHERE plan_code = 'BASIC_MONTHLY'),
    'active',
    3,
    NOW(),
    NOW() + INTERVAL '30 days'
)
ON CONFLICT (license_key) DO NOTHING;

