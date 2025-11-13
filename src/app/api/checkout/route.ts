// Stripe Checkout session creation with proper metadata for licensing
// This ensures the webhook receives the correct SKU for license generation

import { NextRequest } from "next/server";
import Stripe from "stripe";
import { config } from "../../../lib/config";
import { applyRateLimit } from "../../../lib/rate-limit";
import { emptyResponse, jsonResponse } from "../../../lib/http";

const stripe = new Stripe(config.stripe.secretKey, {
  apiVersion: "2023-10-16",
});

// Product configuration with SKUs for licensing
const PRODUCTS = {
  basic: {
    priceId: config.stripe.priceIds.basic,
    sku: "BASIC",
    name: "RescuePC Basic License",
    enabled: true,
  },
  pro: {
    priceId: config.stripe.priceIds.pro,
    sku: "PRO",
    name: "RescuePC Professional License",
    enabled: true,
  },
  enterprise: {
    priceId: config.stripe.priceIds.enterprise,
    sku: "ENTERPRISE",
    name: "RescuePC Enterprise License",
    enabled: config.features.enterpriseEnabled,
  },
  lifetime: {
    priceId: config.stripe.priceIds.lifetime,
    sku: "LIFETIME",
    name: "RescuePC Lifetime License",
    enabled: true,
  },
};

export async function POST(req: NextRequest) {
  try {
    const rateLimit = applyRateLimit(req, "checkout");
    if (!rateLimit.allowed) {
      return jsonResponse(
        { error: "Too many checkout attempts. Please try again later." },
        {
          status: 429,
          headers: rateLimit.retryAfter
            ? { "Retry-After": rateLimit.retryAfter.toString() }
            : undefined,
        }
      );
    }

    const { plan, customerEmail } = await req.json();

    if (!plan || !PRODUCTS[plan as keyof typeof PRODUCTS]) {
      return jsonResponse(
        { error: "Invalid plan specified" },
        { status: 400 }
      );
    }

    const product = PRODUCTS[plan as keyof typeof PRODUCTS];

    if (!product.enabled) {
      return jsonResponse(
        { error: "Selected plan is not currently available." },
        { status: 403 }
      );
    }

    if (!product.priceId) {
      return jsonResponse(
        { error: "Checkout configuration incomplete for this plan." },
        { status: 500 }
      );
    }

    // Create Stripe Checkout session with metadata for licensing
    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      payment_method_types: ["card"],
      line_items: [
        {
          price: product.priceId,
          quantity: 1,
        },
      ],
      customer_email: customerEmail, // Optional: pre-fill email
      metadata: {
        sku: product.sku, // Critical: webhook uses this for license generation
        product: product.name,
        plan: plan.toUpperCase(),
      },
      success_url: `${config.urls.nextAuthUrl}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${config.urls.nextAuthUrl}/pricing`,
      allow_promotion_codes: true,
    });

    return jsonResponse({
      url: session.url,
      sessionId: session.id,
    });

  } catch (error: unknown) {
    console.error("Checkout session creation failed:", error);
    return jsonResponse(
      { error: "Failed to create checkout session" },
      { status: 500 }
    );
  }
}

// Handle OPTIONS for CORS
export async function OPTIONS() {
  return emptyResponse(204, {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  });
}
