// Prisma client singleton for Next.js
// Prevents multiple instances in development hot-reload

import { PrismaClient, Prisma } from "@prisma/client";
import { headers } from "next/headers";

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["query", "error", "warn"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}

// Tenant-aware database operations
export class TenantDB {
  private prisma = prisma;
  private tenantId: string;

  constructor(tenantId?: string) {
    // Get tenant from parameter or use default
    this.tenantId = tenantId || 'default';
  }

  static async fromRequest(): Promise<TenantDB> {
    // Get tenant from request headers (set by middleware)
    const headersList = await headers();
    const tenantId = headersList.get('x-tenant-id') || 'default';
    return new TenantDB(tenantId);
  }

  getTenantId(): string {
    return this.tenantId;
  }

  // License operations with tenant isolation
  async getLicenseByKey(licenseKey: string, tenantId?: string) {
    return this.prisma.license.findFirst({
      where: {
        licenseKey,
        ...(tenantId ? { tenantId } : {}),
      },
    });
  }

  async createLicense(data: Prisma.LicenseCreateInput) {
    return this.prisma.license.create({
      data: {
        ...data,
        tenantId: this.tenantId,
      },
    });
  }

  async getLicensesByEmail(email: string) {
    return this.prisma.license.findMany({
      where: {
        customerEmail: email,
        tenantId: this.tenantId,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async updateLicense(id: string, data: Prisma.LicenseUpdateInput) {
    return this.prisma.license.update({
      where: { id },
      data: {
        ...data,
        tenantId: this.tenantId,
      },
    });
  }

  // Customer operations with tenant isolation
  async getCustomerByEmail(email: string) {
    return this.prisma.test_customers.findFirst({
      where: {
        email,
        tenantId: this.tenantId,
      },
    });
  }

  async createCustomer(email: string) {
    return this.prisma.test_customers.create({
      data: {
        email,
        tenantId: this.tenantId,
      },
    });
  }
}

