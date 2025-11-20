import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";
import { prisma } from "@/lib/prisma";
import { createHash } from "crypto";

const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY is not set");
}
if (!webhookSecret) {
  throw new Error("STRIPE_WEBHOOK_SECRET is not set");
}

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2023-10-16",
});

// ensure node runtime
export const runtime = "nodejs";

function generateLicenseKey(prefix: string) {
  // Simple dev generator. You can replace with your own.
  const random = Math.random().toString(36).slice(2, 10).toUpperCase();
  const random2 = Math.random().toString(36).slice(2, 10).toUpperCase();
  return `${prefix}-${random}-${random2}`;
}

function generateSecureDownloadToken(email: string) {
  return createHash("sha256")
    .update(`${email}${process.env.DOWNLOAD_SECRET}`)
    .digest("hex");
}

async function sendLicenseEmail(email: string, licenseKey: string, planName: string) {
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000";
  const downloadToken = generateSecureDownloadToken(email);
  const downloadUrl = `${baseUrl}/api/download/secure?token=${downloadToken}&email=${encodeURIComponent(email)}`;

  // For now, just log - you can integrate with Resend later
  console.log("=== LICENSE EMAIL ===");
  console.log(`To: ${email}`);
  console.log(`License Key: ${licenseKey}`);
  console.log(`Plan: ${planName}`);
  console.log(`Download URL: ${downloadUrl}`);
  console.log("==================");
}

export async function POST(req: NextRequest) {
  const sig = req.headers.get("stripe-signature");

  if (!sig) {
    return new NextResponse("Missing stripe-signature header", { status: 400 });
  }

  let event: Stripe.Event;

  try {
    const buf = Buffer.from(await req.arrayBuffer());
    event = stripe.webhooks.constructEvent(buf, sig, webhookSecret!);
  } catch (err: any) {
    console.error("Stripe webhook signature error", err?.message);
    return new NextResponse(`Webhook Error: ${err.message}`, { status: 400 });
  }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;

        const email =
          session.customer_details?.email ||
          (session.customer_email as string | null);

        if (!email) {
          console.warn("checkout.session.completed without email, skipping");
          break;
        }

        const planCode = session.metadata?.plan_code || "STANDARD_MONTHLY";
        const planName =
          session.metadata?.plan_name || "RescuePC Standard Monthly";
        const productSku =
          session.metadata?.product_sku || "RESCUEPC_STANDARD";

        // Generate license key
        const licenseKey = generateLicenseKey("RPC");

        const maxDevices =
          planCode === "OWNER_LIFETIME" ? 50 : planCode === "PRO" ? 10 : 3;

        // Insert into licenses table
        const license = await prisma.license.create({
          data: {
            // Required fields from schema
            customerEmail: email,
            licenseKey: licenseKey,
            status: "active",
            planCode: planCode,
            planName: planName,
            issuedAt: new Date(),
            
            // Optional fields
            stripeEventId: event.id,
            paymentIntent: session.payment_intent as string | null,
            checkoutSession: session.id,
            amountCents: session.amount_total || 0,
            currency: session.currency || "usd",
            expiresAt: null, // for subscriptions you can set to current_period_end later
            
            // Additional metadata
            tenantId: "default",
            updatedAt: new Date(),
          },
        });

        console.log("Created license from webhook:", license.licenseKey);

        // Send license email with secure download link
        await sendLicenseEmail(email, licenseKey, planName);
        break;
      }

      default:
        // For now log and ignore other event types
        console.log(`Unhandled Stripe event type: ${event.type}`);
    }

    return new NextResponse("OK", { status: 200 });
  } catch (err: any) {
    console.error("Error processing Stripe webhook", err);
    return new NextResponse("Internal error", { status: 500 });
  }
}
