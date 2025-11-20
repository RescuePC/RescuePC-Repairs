import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(req: NextRequest) {
  try {
    const { email, licenseKey } = await req.json();

    if (!email || !licenseKey) {
      return NextResponse.json(
        { ok: false, error: "Missing email or license key" },
        { status: 400 }
      );
    }

    const license = await prisma.license.findFirst({
      where: {
        customerEmail: email,
        licenseKey: licenseKey,
        status: "active",
      },
    });

    if (!license) {
      return NextResponse.json(
        { ok: false, error: "License not found or inactive" },
        { status: 404 }
      );
    }

    // Return the license data with a default value for maxDevices if it doesn't exist
    const responseData = {
      ok: true,
      planCode: license.planCode || '',
      planName: license.planName || '',
      maxDevices: 'maxDevices' in license ? license.maxDevices : 1, // Default to 1 if not specified
    };

    return NextResponse.json(responseData, { status: 200 });
  } catch (err: any) {
    console.error("Error validating license", err);
    return NextResponse.json(
      { ok: false, error: "Server error" },
      { status: 500 }
    );
  }
}
