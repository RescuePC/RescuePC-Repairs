const { PrismaClient } = require('@prisma/client');

// Load DATABASE_URL from environment
require('dotenv').config({ path: '.env.local' });

const prisma = new PrismaClient();

async function addTenantColumn() {
  try {
    console.log('Adding tenant_id column to licenses table...');
    await prisma.$executeRaw`ALTER TABLE licenses ADD COLUMN IF NOT EXISTS tenant_id VARCHAR(255) DEFAULT 'RESCUEPC_MAIN'`;
    
    console.log('Updating RescuePC-2025 license with tenant_id...');
    await prisma.$executeRaw`UPDATE licenses SET tenant_id = 'RESCUEPC_MAIN' WHERE license_key = 'RescuePC-2025'`;
    
    console.log('✅ Added tenant_id column and updated RescuePC-2025');
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

addTenantColumn();
