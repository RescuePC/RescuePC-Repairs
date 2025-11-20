-- Create OWNER_LIFETIME license for RescuePC owner
-- This license never expires and has full owner privileges

INSERT INTO licenses (
    id,
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
    gen_random_uuid(),  -- Generate unique ID
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
);

-- Verify the license was created
SELECT * FROM licenses WHERE license_key = 'RescuePC-2025' AND is_owner = true;
