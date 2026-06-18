import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { createHash } from "crypto";
import fs from "fs";
import path from "path";

export const runtime = "nodejs";

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const token = searchParams.get("token");
    const email = searchParams.get("email")?.trim().toLowerCase();

    if (!token || !email) {
      return NextResponse.json(
        { error: "Missing download token or email" },
        { status: 400 }
      );
    }

    const expectedHash = createHash("sha256")
      .update(`${email}${process.env.DOWNLOAD_SECRET}`)
      .digest("hex");

    if (token !== expectedHash) {
      return NextResponse.json(
        { error: "Invalid download token" },
        { status: 401 }
      );
    }

    const license = await prisma.license.findFirst({
      where: {
        customerEmail: email,
        status: "active",
      },
    });

    if (!license) {
      return NextResponse.json(
        { error: "No active license found" },
        { status: 403 }
      );
    }

    const filePath = path.join(process.cwd(), "public", "downloads", "RescuePC-Setup.exe");

    if (!fs.existsSync(filePath)) {
      return NextResponse.json(
        { error: "Download file not found" },
        { status: 404 }
      );
    }

    const fileBuffer = fs.readFileSync(filePath);

    return new NextResponse(fileBuffer, {
      headers: {
        "Content-Type": "application/octet-stream",
        "Content-Disposition": 'attachment; filename="RescuePC-Setup.exe"',
        "Content-Length": fileBuffer.length.toString(),
        "Cache-Control": "private, no-store, max-age=0",
        "X-Content-Type-Options": "nosniff",
      },
    });
  } catch (err: unknown) {
    console.error("Secure download error:", err);
    return NextResponse.json(
      { error: "Download failed" },
      { status: 500 }
    );
  }
}
