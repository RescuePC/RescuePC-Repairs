require('dotenv').config({ path: '.env.local' });
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function updateLicenseStatus() {
  try {
    await prisma.license.update({
      where: { licenseKey: 'RescuePC-2025' },
      data: { status: 'active' }
    });
    console.log('✅ License status updated to active');
  } catch (error) {
    console.error('❌ Error updating license:', error);
  } finally {
    await prisma.$disconnect();
  }
}

updateLicenseStatus();
