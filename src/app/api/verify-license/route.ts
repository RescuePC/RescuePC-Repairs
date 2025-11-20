import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { getPlanRights, PlanCode } from "@/lib/license";

/**
 * POST /api/verify-license
 * Body: { licenseKey: string, machineId: string }
 * Response: { 
 *   ok: boolean, 
 *   licenseKey: string, 
 *   plan: string,
 *   planLabel: string,
 *   planDescription: string,
 *   lifetime: boolean,
 *   activatedAt: string,
 *   expiresAt: string | null,
 *   rights: {
 *     personalUse: boolean,
 *     commercialUse: boolean,
 *     businessUse: boolean,
 *     remoteAssistIncluded: boolean,
 *     dedicatedSupport: boolean
 *   },
 *   machine: {
 *     machineId: string
 *   },
 *   error?: string
 * }
 */
export async function POST(req: Request) {
  try {
    const body = await req.json().catch(() => ({}));
    const { licenseKey, machineId } = body as {
      licenseKey?: string;
      machineId?: string;
    };

    if (!licenseKey || !machineId) {
      return NextResponse.json(
        { ok: false, error: 'MISSING_FIELDS' },
        { status: 400 }
      );
    }

    // Find the license by licenseKey (which is stored in the licenseKey field)
    const license = await prisma.license.findFirst({
      where: { licenseKey: licenseKey },
      include: { plan: true }
    });

    if (!license) {
      return NextResponse.json(
        { ok: false, error: 'LICENSE_NOT_FOUND' },
        { status: 404 }
      );
    }

    // Check if license is active (case-insensitive check)
    if (license.status.toUpperCase() !== 'ACTIVE') {
      return NextResponse.json(
        { ok: false, error: 'LICENSE_INACTIVE' },
        { status: 403 }
      );
    }

    const now = new Date();
    const planName = license.plan?.name || 'BASIC';
    const isLifetime = planName === 'LIFETIME';
    const isExpired = !isLifetime && license.expiresAt && new Date(license.expiresAt) <= now;

    if (isExpired) {
      return NextResponse.json(
        { ok: false, error: 'LICENSE_EXPIRED' },
        { status: 403 }
      );
    }

    // Get plan rights based on the plan name
    const planCode = planName as PlanCode;
    const rights = getPlanRights(planCode);

    return NextResponse.json(
      {
        ok: true,
        licenseKey: license.licenseKey,
        plan: rights.code,
        planLabel: rights.label,
        planDescription: rights.description,
        lifetime: rights.lifetime,
        // dates
        activatedAt: license.createdAt?.toISOString() || new Date().toISOString(),
        expiresAt: license.expiresAt?.toISOString() || null,
        // rights
        rights: {
          personalUse: rights.personalUse,
          commercialUse: rights.commercialUse,
          businessUse: rights.businessUse,
          remoteAssistIncluded: rights.remoteAssistIncluded,
          dedicatedSupport: rights.dedicatedSupport
        },
        // machine info
        machine: {
          machineId,
          lastVerifiedAt: new Date().toISOString()
        },
        // legacy fields for backward compatibility
        valid: true,
        licenseId: license.id,
        status: 'active',
        planCode: rights.code,
        planName: rights.label
      },
      { status: 200 }
    );

  } catch (err) {
    console.error("verify-license error:", err);
    return NextResponse.json(
      { valid: false, error: "SERVER_ERROR" },
      { status: 500 }
    );
  }
}
