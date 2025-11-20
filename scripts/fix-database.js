const { PrismaClient } = require('@prisma/client');

// Load DATABASE_URL from environment
require('dotenv').config({ path: '.env.local' });

const prisma = new PrismaClient();

async function fixDatabase() {
  try {
    console.log('Adding missing columns to licenses table...');
    
    // Add all missing columns
    await prisma.$executeRaw`ALTER TABLE licenses ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMP`;
    await prisma.$executeRaw`ALTER TABLE licenses ADD COLUMN IF NOT EXISTS machine_id VARCHAR(255)`;
    await prisma.$executeRaw`ALTER TABLE licenses ADD COLUMN IF NOT EXISTS tenant_id VARCHAR(255) DEFAULT 'RESCUEPC_MAIN'`;
    
    // Update existing license with tenant_id
    await prisma.$executeRaw`UPDATE licenses SET tenant_id = 'RESCUEPC_MAIN' WHERE license_key = 'RescuePC-2025'`;
    
    console.log('✅ Fixed database schema and updated license');
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

fixDatabase();
