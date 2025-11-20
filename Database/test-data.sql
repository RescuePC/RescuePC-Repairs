-- Test Data for Neon Database
-- Run this in Neon SQL Editor after creating the schema

-- Insert test license (assuming customer_id=1 and package_id=1 already exist)
INSERT INTO licenses (
    customer_id,
    package_id,
    license_key,
    purchased_at,
    expires_at,
    status
) VALUES (
    1,                      -- customers.id (test@example.com)
    1,                      -- packages.id (BASIC)
    'TEST-KEY',             -- test license key
    NOW(),
    NOW() + INTERVAL '30 days',
    'active'
);

-- Verify the insert worked
SELECT 
    l.id,
    c.email,
    p.code as package_code,
    l.license_key,
    l.status,
    l.expires_at,
    CASE 
        WHEN l.expires_at > NOW() THEN 'Not Expired'
        ELSE 'Expired'
    END as expiry_status
FROM licenses l
JOIN customers c ON c.id = l.customer_id
JOIN packages p ON p.id = l.package_id
WHERE l.license_key = 'TEST-KEY';

