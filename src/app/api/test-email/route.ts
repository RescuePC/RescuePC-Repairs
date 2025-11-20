import { sendLicenseEmail } from "../../../lib/mailer";
import { jsonResponse } from "../../../lib/http";

const TEST_EMAIL = "rescuepcrepairs@gmail.com";

import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    console.log("Test email endpoint hit");

    // TODO: plug in your real mailer here later
    return NextResponse.json(
      { ok: true, message: "Test email endpoint is wired up." },
      { status: 200 }
    );
  } catch (err) {
    console.error("test-email error:", err);
    return NextResponse.json(
      { ok: false, error: "Test email failed" },
      { status: 500 }
    );
  }
}

export async function GET() {
  try {
    await sendLicenseEmail({
      to: TEST_EMAIL,
      licenseKey: "TEST-KEY-12345-ABCDE",
      planName: "Basic",
      downloadUrl: "https://rescuepc.local/download",
    });

    return jsonResponse({
      ok: true,
      message: `Test license email dispatched to ${TEST_EMAIL}`,
    });
  } catch (error: unknown) {
    console.error("Failed to send test license email:", error);
    return jsonResponse(
      { error: "Failed to send test email" },
      { status: 500 }
    );
  }
}

