const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });

async function checkAllLicenses() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL
  });

  try {
    await client.connect();
    console.log('Connected to database');

    // Check all licenses
    const result = await client.query('SELECT license_key, customer_email, status FROM licenses');
    console.log('All licenses:', result.rows);

    // Check specifically for TEST-KEY
    const testResult = await client.query('SELECT * FROM licenses WHERE license_key = $1', ['TEST-KEY']);
    console.log('TEST-KEY found:', testResult.rowCount > 0 ? 'YES' : 'NO');
    if (testResult.rowCount > 0) {
      console.log('TEST-KEY details:', testResult.rows[0]);
    }

    // Check for RescuePC-2025
    const ownerResult = await client.query('SELECT * FROM licenses WHERE license_key = $1', ['RescuePC-2025']);
    console.log('RescuePC-2025 found:', ownerResult.rowCount > 0 ? 'YES' : 'NO');
    if (ownerResult.rowCount > 0) {
      console.log('RescuePC-2025 details:', ownerResult.rows[0]);
    }

  } catch (error) {
    console.error('Database check error:', error);
  } finally {
    await client.end();
  }
}

checkAllLicenses();
