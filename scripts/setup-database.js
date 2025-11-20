const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });

async function setupDatabase() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL
  });

  try {
    await client.connect();
    console.log('Connected to database');

    // Create the licenses table
    const createTableSQL = `
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
    `;

    await client.query(createTableSQL);
    console.log('Created licenses table');

    // Create indexes
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_licenses_customer_email ON licenses(customer_email);',
      'CREATE INDEX IF NOT EXISTS idx_licenses_product_sku ON licenses(product_sku);',
      'CREATE INDEX IF NOT EXISTS idx_licenses_status ON licenses(status);',
      'CREATE INDEX IF NOT EXISTS idx_licenses_license_key ON licenses(license_key);',
      'CREATE INDEX IF NOT EXISTS idx_licenses_is_owner ON licenses(is_owner);'
    ];

    for (const indexSQL of indexes) {
      await client.query(indexSQL);
    }
    console.log('Created indexes');

    // Create trigger function
    const triggerFunctionSQL = `
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
          NEW.updated_at = NOW();
          RETURN NEW;
      END;
      $$ language 'plpgsql';
    `;

    await client.query(triggerFunctionSQL);
    console.log('Created trigger function');

    // Drop and recreate trigger
    await client.query('DROP TRIGGER IF EXISTS update_licenses_updated_at ON licenses;');
    await client.query(`
      CREATE TRIGGER update_licenses_updated_at 
        BEFORE UPDATE ON licenses 
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    `);
    console.log('Created trigger');

    // Insert owner license
    const insertLicenseSQL = `
      INSERT INTO licenses (
        customer_email,
        product_sku,
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
        'RESCUEPC_OWNER',
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
    `;

    await client.query(insertLicenseSQL);
    console.log('Inserted owner license');

    // Verify the license was created
    const result = await client.query('SELECT * FROM licenses WHERE license_key = $1', ['RescuePC-2025']);
    console.log('License verification:', result.rows);

  } catch (error) {
    console.error('Database setup error:', error);
  } finally {
    await client.end();
  }
}

setupDatabase();
