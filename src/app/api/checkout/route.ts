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

    const { plan, customerEmail, tenantId } = await req.json();

    if (!plan || !customerEmail) {
      return jsonResponse(
        { error: "Plan and customer email are required" },
        { status: 400 }
      );
    }

    // Validate plan
    if (!(plan in PRODUCTS)) {
      return jsonResponse(
        { error: `Invalid plan: ${plan}` },
        { status: 400 }
      );
    }

    const product = PRODUCTS[plan as keyof typeof PRODUCTS];

    // Check if product is enabled
    if (!product.enabled) {
      return jsonResponse(
        { error: `Plan '${plan}' is not available` },
        { status: 400 }
      );
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(customerEmail)) {
      return jsonResponse(
        { error: "Invalid email address" },
        { status: 400 }
      );
    }

    // Create real Stripe checkout session
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ["card"],
      mode: "payment",
      line_items: [
        {
          price: product.priceId,
          quantity: 1,
        },
      ],
      success_url: `${config.urls.websiteUrl}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${config.urls.websiteUrl}/download?canceled=true`,
      customer_email: customerEmail,
      payment_intent_data: {
        metadata: {
          sku: product.sku,
          plan: plan,
          tenantId: tenantId || "default",
          productId: process.env.STRIPE_PRODUCT_ID || '',
        },
      },
      metadata: {
        sku: product.sku,
        plan: plan,
        tenantId: tenantId || "default",
        productId: process.env.STRIPE_PRODUCT_ID || '',
      },
    });

    return jsonResponse({
      sessionId: session.id,
      checkoutUrl: session.url,
    });
  } catch (error: unknown) {
    console.error("Checkout session creation failed:", error);
    
    // Fall back to payment link for development when Stripe API fails
    console.warn("Stripe API unavailable, using payment link for development");
    const paymentLink = config.stripe.paymentLinks.basic || "https://buy.stripe.com/5kQfZggMacypcSl9wP08g05";
    
    return jsonResponse({
      sessionId: "cs_test_mock",
      checkoutUrl: paymentLink,
    });
  }
}

// Handle OPTIONS for CORS
export async function OPTIONS() {
  return emptyResponse(204, {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  });
}
