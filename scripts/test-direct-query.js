const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });

async function testDirectQuery() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL
  });

  try {
    await client.connect();
    console.log('Connected to database');

    // Test the exact same query the API is using
    const normalizedEmail = 'keeseetyler@yahoo.com'.trim().toLowerCase();
    const sanitizedLicenseKey = 'RescuePC-2025'.trim().toUpperCase();
    
    console.log('Testing with email:', normalizedEmail, 'licenseKey:', sanitizedLicenseKey);

    const licenseResult = await client.query(
      `
      SELECT
        l.id,
        l.customer_email,
        l.license_key,
        l.status,
        l.expires_at,
        l.max_devices,
        l.is_owner,
        l.plan_code,
        l.plan_name,
        l.issued_at
      FROM licenses l
      WHERE l.customer_email = $1
        AND l.license_key = $2
        AND l.status = 'active'
      LIMIT 1
      `,
      [normalizedEmail, sanitizedLicenseKey]
    );
    
    console.log('Direct query row count:', licenseResult.rowCount);
    if (licenseResult.rows.length > 0) {
      console.log('Direct query result:', licenseResult.rows[0]);
    } else {
      console.log('Direct query found no rows');
    }

    // Test with different variations
    console.log('\n--- Testing variations ---');
    
    // Test with exact email from DB
    const exactEmailResult = await client.query(
      'SELECT * FROM licenses WHERE customer_email = $1 AND license_key = $2 AND status = $3',
      ['keeseetyler@yahoo.com', 'RescuePC-2025', 'active']
    );
    console.log('Exact email match:', exactEmailResult.rowCount, 'rows');

    // Test without status filter
    const noStatusResult = await client.query(
      'SELECT * FROM licenses WHERE customer_email = $1 AND license_key = $2',
      [normalizedEmail, sanitizedLicenseKey]
    );
    console.log('Without status filter:', noStatusResult.rowCount, 'rows');

    // Test just license key
    const keyOnlyResult = await client.query(
      'SELECT * FROM licenses WHERE license_key = $1',
      [sanitizedLicenseKey]
    );
    console.log('License key only:', keyOnlyResult.rowCount, 'rows');

  } catch (error) {
    console.error('Database test error:', error);
  } finally {
    await client.end();
  }
}

testDirectQuery();
