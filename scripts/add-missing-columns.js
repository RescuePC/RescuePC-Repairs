const { PrismaClient } = require('@prisma/client');

// Load DATABASE_URL from environment
require('dotenv').config({ path: '.env.local' });

const prisma = new PrismaClient();

async function addMissingColumns() {
  try {
    console.log('Adding missing columns to licenses table...');
    
    // Add last_verified_at column
    await prisma.$executeRaw`ALTER TABLE licenses ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMP`;
    
    // Add machine_id column  
    await prisma.$executeRaw`ALTER TABLE licenses ADD COLUMN IF NOT EXISTS machine_id VARCHAR(255)`;
    
    console.log('✅ Added missing columns');
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

addMissingColumns();
