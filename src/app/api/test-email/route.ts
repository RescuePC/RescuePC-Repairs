import { sendLicenseEmail } from "../../../lib/mailer";
import { jsonResponse } from "../../../lib/http";

const TEST_EMAIL = "rescuepcrepairs@gmail.com";

export async function GET() {
  try {
    await sendLicenseEmail({
      to: TEST_EMAIL,
      licenseKey: "TEST-KEY-12345-ABCDE",
      product: "Basic",
      amountCents: 4999,
      currency: "usd",
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

