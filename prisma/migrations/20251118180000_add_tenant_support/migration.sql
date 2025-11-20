-- AlterTable
ALTER TABLE "licenses" ADD COLUMN     "tenantId" TEXT DEFAULT 'default';

-- AlterTable
ALTER TABLE "licenses" ADD COLUMN     "lastVerifiedAt" TIMESTAMP(6);

-- AlterTable
ALTER TABLE "licenses" ADD COLUMN     "machineId" TEXT;

-- AlterTable
ALTER TABLE "licenses" ADD COLUMN     "maxDevices" INTEGER;

-- AlterTable
ALTER TABLE "licenses" ADD COLUMN     "isOwner" BOOLEAN DEFAULT false;

-- AlterTable
ALTER TABLE "licenses" ADD COLUMN     "planCode" TEXT DEFAULT 'STANDARD';

-- AlterTable
ALTER TABLE "licenses" ADD COLUMN     "planName" TEXT;

-- AlterTable
ALTER TABLE "licenses" ADD COLUMN     "issuedAt" TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP;

-- AlterTable
ALTER TABLE "test_customers" ADD COLUMN     "tenantId" TEXT DEFAULT 'default';

-- CreateIndex
CREATE INDEX "licenses_tenantId_idx" ON "licenses"("tenantId");

-- CreateIndex
CREATE INDEX "test_customers_tenantId_idx" ON "test_customers"("tenantId");
