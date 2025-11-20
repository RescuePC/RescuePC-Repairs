-- Create the licenses table with all required fields for owner license system
-- This script creates the table from scratch since it doesn't exist yet

CREATE TABLE IF NOT EXISTS licenses (
    id TEXT PRIMARY KEY DEFAULT (gen_random_uuid()),
    stripe_event_id TEXT UNIQUE,
    payment_intent TEXT UNIQUE,
    checkout_session TEXT UNIQUE,
    customer_email TEXT NOT NULL,
    product_sku TEXT NOT NULL,
    amount_cents INTEGER,
    currency TEXT DEFAULT 'usd',
    license_key TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'issued' CHECK (status IN ('issued', 'active', 'duplicate', 'error', 'revoked')),
    expires_at TIMESTAMPTZ, -- NULL for lifetime licenses
    max_devices INTEGER, -- for owner licenses
    is_owner BOOLEAN DEFAULT false,
    plan_code TEXT DEFAULT 'STANDARD',
    plan_name TEXT, -- display name for the plan
    issued_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_licenses_customer_email ON licenses(customer_email);
CREATE INDEX IF NOT EXISTS idx_licenses_product_sku ON licenses(product_sku);
CREATE INDEX IF NOT EXISTS idx_licenses_status ON licenses(status);
CREATE INDEX IF NOT EXISTS idx_licenses_license_key ON licenses(license_key);
CREATE INDEX IF NOT EXISTS idx_licenses_is_owner ON licenses(is_owner);

-- Create trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_licenses_updated_at 
    BEFORE UPDATE ON licenses 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Insert the owner license
INSERT INTO licenses (
    customer_email,
    license_key,
    status,
    expires_at,
    max_devices,
    is_owner,
    plan_code,
    plan_name,
    issued_at,
    created_at,
    updated_at
) VALUES (
    'keeseetyler@yahoo.com',
    'RescuePC-2025',
    'active',
    NULL,  -- NULL means never expires
    50,    -- Max devices for owner
    true,  -- This is an owner license
    'OWNER_LIFETIME',
    'Owner Lifetime License',
    NOW(),
    NOW(),
    NOW()
) ON CONFLICT (license_key) DO NOTHING;

-- Verify the license was created
SELECT * FROM licenses WHERE license_key = 'RescuePC-2025';
