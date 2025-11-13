// License activation endpoint for RescuePC desktop application
// Validates license keys and returns encrypted entitlement tokens

import { NextRequest } from "next/server";
import { PrismaClient } from "@prisma/client";
import jwt from "jsonwebtoken";
import { config } from "../../../lib/config";
import { jsonResponse, emptyResponse } from "../../../lib/http";
import { applyRateLimit } from "../../../lib/rate-limit";

const prisma = new PrismaClient();

export async function POST(req: NextRequest) {
  try {
    const rateLimit = applyRateLimit(req, "activate");
    if (!rateLimit.allowed) {
      return jsonResponse(
        { error: "Too many activation attempts. Please try again later." },
        {
          status: 429,
          headers: rateLimit.retryAfter
            ? { "Retry-After": rateLimit.retryAfter.toString() }
            : undefined,
        }
      );
    }

    const { licenseKey, machineId } = await req.json();

    if (!licenseKey) {
      return jsonResponse(
        { error: "License key is required" },
        { status: 400 }
      );
    }

    // Find the license in database
    const license = await prisma.license.findUnique({
      where: { licenseKey },
    });

    if (!license) {
      return jsonResponse(
        { error: "Invalid license key" },
        { status: 403 }
      );
    }

    // Check if license is active
    if (license.status !== "issued") {
      return jsonResponse(
        { error: `License is ${license.status}` },
        { status: 403 }
      );
    }

    // Calculate expiration timestamp (null for lifetime)
    const expiresAt = license.productSku.toLowerCase().includes("lifetime")
      ? null
      : new Date(Date.now() + 365 * 24 * 60 * 60 * 1000); // 1 year from now

    const exp = expiresAt
      ? Math.floor(expiresAt.getTime() / 1000)
      : Math.floor(Date.now() / 1000) + (10 * 365 * 24 * 60 * 60); // 10 years for lifetime

    // Create signed JWT token with license entitlements
    const token = jwt.sign(
      {
        k: license.licenseKey,
        plan: license.productSku,
        admin: license.productSku.toLowerCase().includes("enterprise"),
        mid: machineId,
        email: license.customerEmail,
        iat: Math.floor(Date.now() / 1000),
        exp,
      },
      config.security.jwtSecret,
      { algorithm: "HS256" }
    );

    return jsonResponse({
      token,
      plan: license.productSku,
      expiresAt: expiresAt?.toISOString(),
      email: license.customerEmail,
    });

  } catch (err: unknown) {
    console.error("License activation error:", err);
    return jsonResponse(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}

// Handle preflight requests
export async function OPTIONS() {
  return emptyResponse(204, {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  });
}
