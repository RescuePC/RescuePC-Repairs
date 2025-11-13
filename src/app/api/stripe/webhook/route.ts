// Stripe webhook endpoint for automated license processing
// Handles checkout.session.completed events and generates licenses automatically

import { NextRequest } from "next/server";
import Stripe from "stripe";
import { PrismaClient } from "@prisma/client";
import { generateLicenseKey, getLicenseTierFromSku } from "../../../../lib/license";
import { sendLicenseEmail, sendErrorNotification } from "../../../../lib/mailer";
import { config } from "../../../../lib/config";
import { emptyResponse, jsonResponse } from "../../../../lib/http";

// Initialize Prisma client (connection pooling handled by Vercel)
const prisma = new PrismaClient();

// Initialize Stripe client
const stripe = new Stripe(config.stripe.secretKey, {
  apiVersion: "2023-10-16",
});

export const runtime = "nodejs"; // Required for Stripe signature verification

export async function POST(req: NextRequest) {
  const body = await req.text();
  const sig = req.headers.get("stripe-signature");

  let event: Stripe.Event;

  try {
    // Verify webhook signature for security
    event = stripe.webhooks.constructEvent(body, sig!, config.stripe.webhookSecret);
  } catch (err: unknown) {
    const message =
      err instanceof Error ? err.message : "Unknown signature verification error";
    console.error("Webhook signature verification failed:", err);
    return jsonResponse({ error: `Signature verification failed: ${message}` }, { status: 400 });
  }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;

        // Extract payment details
        const paymentIntent = (session.payment_intent as string) ?? session.id;
        const customerEmail =
          session.customer_details?.email ||
          (session.customer && typeof session.customer === "object" && "email" in session.customer ? session.customer.email : undefined) ||
          undefined;

        // Get product SKU from metadata (set in your storefront)
        const productSku =
          session.metadata?.sku ??
          session.metadata?.product ??
          "BASIC"; // Default fallback

        const amountCents = typeof session.amount_total === "number" ? session.amount_total : 0;
        const currency = (session.currency || "usd").toLowerCase();

        console.log(`Processing checkout: ${session.id}, Email: ${customerEmail}, SKU: ${productSku}`);

        // Idempotency check: prevent duplicate license generation
        const existing = await prisma.license.findFirst({
          where: {
            OR: [
              { stripeEventId: event.id },
              { paymentIntent: paymentIntent },
            ],
          },
        });

        if (existing) {
          console.log(`Duplicate event detected: ${event.id}`);
          return jsonResponse({ ok: true, duplicate: true });
        }

        // Generate unique license key
        const licenseKey = generateLicenseKey();

        // Determine license tier from SKU
        const licenseTier = getLicenseTierFromSku(productSku);

        // Create license record in database
        const created = await prisma.license.create({
          data: {
            stripeEventId: event.id,
            paymentIntent: paymentIntent,
            checkoutSession: session.id,
            customerEmail: customerEmail ?? "unknown@unknown",
            productSku: licenseTier,
            amountCents,
            currency,
            licenseKey,
            status: "issued",
          },
        });

        console.log(`License created: ${created.id} for ${customerEmail}`);

        // Send license email if we have an email address
        if (customerEmail) {
          try {
            await sendLicenseEmail({
              to: customerEmail,
              licenseKey,
              product: licenseTier,
              amountCents,
              currency,
            });
            console.log(`License email sent to: ${customerEmail}`);
          } catch (emailError: unknown) {
            console.error("Failed to send license email:", emailError);
            // Don't fail the webhook for email errors
          }
        } else {
          console.warn("No customer email available for license delivery");
        }

        return jsonResponse({
          ok: true,
          licenseId: created.id,
          licenseKey: created.licenseKey,
        });
      }

      case "payment_intent.succeeded": {
        // Optional: Handle direct payment intents if not using Checkout
        console.log("Payment intent succeeded:", event.id);
        return jsonResponse({ ok: true });
      }

      case "charge.refunded":
      case "checkout.session.expired": {
        // Optional: Handle refunds and expirations
          console.log(`${event.type}:`, event.id);
          return jsonResponse({ ok: true });
      }

      default:
        // Ignore other event types
        console.log(`Unhandled event type: ${event.type}`);
        return jsonResponse({ ok: true });
    }

  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Unknown webhook processing error";
    console.error("Webhook processing error:", err);

    // Create error record for debugging
    try {
      await prisma.license.create({
        data: {
          stripeEventId: event.id,
          paymentIntent: "error",
          customerEmail: "unknown@unknown",
          productSku: "unknown",
          amountCents: 0,
          currency: "usd",
          licenseKey: "ERROR",
          status: "error",
        },
      });

      // Send error notification
      await sendErrorNotification(message, event.id);

    } catch (dbError: unknown) {
      console.error("Failed to log error to database:", dbError);
    }

    return jsonResponse({ error: message }, { status: 500 });
  }
}

// Handle OPTIONS requests for CORS
export async function OPTIONS() {
  return emptyResponse(204, {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Stripe-Signature",
  });
}
