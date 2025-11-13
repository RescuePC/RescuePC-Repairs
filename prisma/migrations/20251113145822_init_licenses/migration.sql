-- CreateTable
CREATE TABLE "License" (
    "id" TEXT NOT NULL,
    "stripeEventId" TEXT NOT NULL,
    "paymentIntent" TEXT NOT NULL,
    "checkoutSession" TEXT,
    "customerEmail" TEXT NOT NULL,
    "productSku" TEXT NOT NULL,
    "amountCents" INTEGER NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'usd',
    "licenseKey" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'issued',
    "issuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "License_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "License_stripeEventId_key" ON "License"("stripeEventId");

-- CreateIndex
CREATE UNIQUE INDEX "License_paymentIntent_key" ON "License"("paymentIntent");

-- CreateIndex
CREATE UNIQUE INDEX "License_checkoutSession_key" ON "License"("checkoutSession");

-- CreateIndex
CREATE UNIQUE INDEX "License_licenseKey_key" ON "License"("licenseKey");

-- CreateIndex
CREATE INDEX "License_customerEmail_idx" ON "License"("customerEmail");

-- CreateIndex
CREATE INDEX "License_productSku_idx" ON "License"("productSku");

-- CreateIndex
CREATE INDEX "License_status_idx" ON "License"("status");
