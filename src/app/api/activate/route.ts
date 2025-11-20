import { NextRequest, NextResponse } from "next/server";
import { prisma } from "../../../lib/prisma";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const licenseKey = body.licenseKey as string | undefined;
    const machineId = body.machineId as string | undefined;

    if (!licenseKey) {
      return NextResponse.json(
        { ok: false, error: "Missing licenseKey" },
        { status: 400 }
      );
    }

    const license = await prisma.license.findUnique({
      where: { licenseKey },
    });

    if (!license) {
      return NextResponse.json(
        { ok: false, error: "License not found" },
        { status: 404 }
      );
    }

    if (license.status !== "active") {
      return NextResponse.json(
        { ok: false, error: "License not active" },
        { status: 403 }
      );
    }

    const now = new Date();

    await prisma.license.update({
      where: { licenseKey },
      data: {
        lastVerifiedAt: now,
        // only set machineId if one was passed, otherwise keep existing
        ...(machineId ? { machineId } : {}),
      },
    });

    return NextResponse.json(
      {
        ok: true,
        licenseKey,
        status: "active",
        alreadyActive: !!license.lastVerifiedAt,
        activatedAt: now.toISOString(),
      },
      { status: 200 }
    );
  } catch (err) {
    console.error("License activation error:", err);
    return NextResponse.json(
      { ok: false, error: "Internal server error" },
      { status: 500 }
    );
  }
}
