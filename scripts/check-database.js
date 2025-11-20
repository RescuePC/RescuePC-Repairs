const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });

async function checkDatabase() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL
  });

  try {
    await client.connect();
    console.log('Connected to database');

    // Check all licenses
    const result = await client.query('SELECT * FROM licenses');
    console.log('All licenses:', result.rows);

    // Check specific license
    const specificResult = await client.query('SELECT * FROM licenses WHERE license_key = $1', ['RescuePC-2025']);
    console.log('Specific license:', specificResult.rows);

    // Check with different email cases
    const emailResult = await client.query('SELECT * FROM licenses WHERE customer_email = $1', ['keeseetyler@yahoo.com']);
    console.log('Email match:', emailResult.rows);

  } catch (error) {
    console.error('Database check error:', error);
  } finally {
    await client.end();
  }
}

checkDatabase();
